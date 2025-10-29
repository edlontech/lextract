defmodule LeXtract.Tokenizer do
  @moduledoc """
  Tokenization wrapper using Hugging Face Tokenizers library.

  Provides token-level text analysis with character offset tracking, which is
  essential for text alignment in the extraction pipeline. Uses a GenServer to
  cache loaded tokenizers and avoid reloading overhead.

  ## Default Tokenizer

  By default, uses `bert-base-uncased` tokenizer for its balance of performance
  and Unicode handling. The tokenizer is loaded once and cached for the lifetime
  of the application.

  ## Examples

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Hello, world!")
      iex> is_map(encoding)
      true

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Test 😁")
      iex> tokens = LeXtract.Tokenizer.get_tokens(encoding)
      iex> is_list(tokens)
      true

  """

  use GenServer
  require Logger

  alias Tokenizers.Encoding
  alias Tokenizers.Tokenizer

  @type encoding :: %{
          tokens: [String.t()],
          ids: [non_neg_integer()],
          offsets: [{non_neg_integer(), non_neg_integer()}],
          encoding: Encoding.t(),
          text: String.t()
        }

  @type tokenizer_ref :: Tokenizer.t()

  @default_tokenizer_identifier "bert-base-uncased"

  @doc """
  Starts the tokenizer cache GenServer.

  This is typically called automatically by the application supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Tokenizes text and returns encoding with character offsets.

  ## Options

    * `:tokenizer` - Custom tokenizer to use instead of default
    * `:add_special_tokens` - Whether to add special tokens (default: false)

  ## Examples

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Hello world")
      iex> LeXtract.Tokenizer.get_tokens(encoding)
      ["hello", "world"]

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Test émojis 🎉")
      iex> tokens = LeXtract.Tokenizer.get_tokens(encoding)
      iex> length(tokens) > 0
      true

  """
  @spec tokenize(String.t(), keyword()) :: {:ok, encoding()} | {:error, term()}
  def tokenize(text, opts \\ []) when is_binary(text) do
    with {:ok, tokenizer} <- get_or_load_tokenizer(opts),
         {:ok, enc} <- Tokenizer.encode(tokenizer, text) do
      {:ok,
       %{
         tokens: Encoding.get_tokens(enc),
         ids: Encoding.get_ids(enc),
         offsets: Encoding.get_offsets(enc),
         encoding: enc,
         text: text
       }}
    end
  end

  @doc """
  Gets the token string at a specific index from encoding.

  Returns `nil` if the index is out of bounds.
  """
  @spec get_token(encoding(), non_neg_integer()) :: String.t() | nil
  def get_token(%{tokens: tokens}, index) when is_integer(index) and index >= 0 do
    Enum.at(tokens, index)
  end

  def get_token(_encoding, _index), do: nil

  @doc """
  Gets all tokens from encoding.

  ## Examples

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Hello world")
      iex> LeXtract.Tokenizer.get_tokens(encoding)
      ["hello", "world"]

  """
  @spec get_tokens(encoding()) :: [String.t()]
  def get_tokens(%{tokens: tokens}), do: tokens

  @doc """
  Gets the character offset tuple `{start, end}` for token at index.

  Returns `nil` if the index is out of bounds.

  ## Examples

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Hello world")
      iex> LeXtract.Tokenizer.get_offset(encoding, 0)
      {0, 5}

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Test")
      iex> LeXtract.Tokenizer.get_offset(encoding, 999)
      nil

  """
  @spec get_offset(encoding(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def get_offset(%{offsets: offsets}, index) when is_integer(index) and index >= 0 do
    Enum.at(offsets, index)
  end

  @doc """
  Gets all offsets from encoding.

  ## Examples

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Hi!")
      iex> offsets = LeXtract.Tokenizer.get_offsets(encoding)
      iex> is_list(offsets)
      true

  """
  @spec get_offsets(encoding()) :: [{non_neg_integer(), non_neg_integer()}]
  def get_offsets(%{offsets: offsets}), do: offsets

  @doc """
  Finds a token sequence in the encoding.

  Performs case-insensitive search by default. Returns the start and end
  indices (exclusive) of the first match, or `:not_found` if no match exists.

  ## Options

    * `:case_sensitive` - Perform case-sensitive search (default: false)

  ## Examples

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("The quick brown fox")
      iex> LeXtract.Tokenizer.find_sequence(encoding, ["quick", "brown"])
      {:ok, 1, 3}

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Hello world")
      iex> LeXtract.Tokenizer.find_sequence(encoding, ["missing"])
      :not_found

  """
  @spec find_sequence(encoding(), [String.t()], keyword()) ::
          {:ok, non_neg_integer(), non_neg_integer()} | :not_found
  def find_sequence(%{tokens: tokens}, needle, opts \\ []) when is_list(needle) do
    case_sensitive = Keyword.get(opts, :case_sensitive, false)

    haystack =
      if case_sensitive do
        tokens
      else
        Enum.map(tokens, &String.downcase/1)
      end

    needle_normalized =
      if case_sensitive do
        needle
      else
        Enum.map(needle, &String.downcase/1)
      end

    case find_sublist(haystack, needle_normalized, 0) do
      nil -> :not_found
      start_idx -> {:ok, start_idx, start_idx + length(needle)}
    end
  end

  @doc """
  Returns the default tokenizer instance.

  The tokenizer is cached and reused across calls. This function will block
  if the tokenizer is currently being loaded.

  ## Examples

      iex> {:ok, tokenizer} = LeXtract.Tokenizer.default_tokenizer()
      iex> is_struct(tokenizer)
      true

  """
  @spec default_tokenizer() :: {:ok, tokenizer_ref()} | {:error, term()}
  def default_tokenizer do
    GenServer.call(__MODULE__, :get_default_tokenizer, :infinity)
  end

  @doc """
  Clears the tokenizer cache.

  Useful for testing or when you need to reload tokenizers. Not typically
  needed in production code.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @impl true
  def init(_opts) do
    {:ok, %{default: nil, custom: %{}}}
  end

  @impl true
  def handle_call(:get_default_tokenizer, _from, state) do
    case state.default do
      nil ->
        case load_default_tokenizer() do
          {:ok, tokenizer} ->
            {:reply, {:ok, tokenizer}, %{state | default: tokenizer}}

          {:error, _reason} = error ->
            {:reply, error, state}
        end

      tokenizer ->
        {:reply, {:ok, tokenizer}, state}
    end
  end

  @impl true
  def handle_call(:clear_cache, _from, _state) do
    {:reply, :ok, %{default: nil, custom: %{}}}
  end

  defp get_or_load_tokenizer(opts) do
    case Keyword.get(opts, :tokenizer) do
      nil -> default_tokenizer()
      tokenizer -> {:ok, tokenizer}
    end
  end

  defp load_default_tokenizer do
    Logger.debug("Loading default tokenizer: #{@default_tokenizer_identifier}")

    case Tokenizer.from_pretrained(@default_tokenizer_identifier) do
      {:ok, tokenizer} ->
        Logger.debug("Successfully loaded tokenizer: #{@default_tokenizer_identifier}")
        {:ok, tokenizer}

      {:error, reason} = error ->
        Logger.error(
          "Failed to load tokenizer #{@default_tokenizer_identifier}: #{inspect(reason)}"
        )

        error
    end
  end

  defp find_sublist(haystack, needle, start_idx)
       when start_idx + length(needle) <= length(haystack) do
    slice = Enum.slice(haystack, start_idx, length(needle))

    if slice == needle do
      start_idx
    else
      find_sublist(haystack, needle, start_idx + 1)
    end
  end

  defp find_sublist(_haystack, _needle, _start_idx), do: nil
end
