defmodule LeXtract.Config do
  @moduledoc """
  Configuration for extraction operations using NimbleOptions for validation.

  ## Examples

      iex> config = LeXtract.Config.new(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: 2000)
      iex> config.model
      "gpt-4"

      iex> config = LeXtract.Config.default()
      iex> config.batch_size
      5

  """

  @doc false
  def validate_temperature(value) do
    cond do
      is_nil(value) -> {:ok, value}
      is_float(value) and value >= 0.0 and value <= 1.0 -> {:ok, value}
      true -> {:error, "must be a float between 0.0 and 1.0, got: #{inspect(value)}"}
    end
  end

  @options_schema NimbleOptions.new!(
                    prompt: [
                      type: :string,
                      doc: "Extraction prompt/description"
                    ],
                    examples: [
                      type: {:list, :any},
                      default: [],
                      doc: "List of example extractions (maps with :text and :extractions keys)"
                    ],
                    template_file: [
                      type: :string,
                      doc: "Path to template file (.json or .yaml)"
                    ],
                    model: [
                      type: :string,
                      required: true,
                      doc: "LLM model identifier (e.g., 'gpt-4o-mini', 'gemini-2.5-flash')"
                    ],
                    provider: [
                      type: :atom,
                      required: true,
                      doc: "LLM provider (:openai, :gemini, :anthropic, etc.)"
                    ],
                    api_key: [
                      type: :string,
                      required: false,
                      doc: "API key for the LLM provider"
                    ],
                    format: [
                      type: {:in, [:json, :yaml]},
                      default: :yaml,
                      doc: "Output format for extractions"
                    ],
                    fence_output: [
                      type: :boolean,
                      default: false,
                      doc: "Expect fenced code blocks in LLM response"
                    ],
                    use_structured_output: [
                      type: :boolean,
                      default: false,
                      doc: "Use structured output mode (generate_object)"
                    ],
                    max_char_buffer: [
                      type: :pos_integer,
                      default: 1000,
                      doc: "Maximum chunk size in characters"
                    ],
                    chunk_overlap: [
                      type: :non_neg_integer,
                      default: 200,
                      doc: "Character overlap between chunks"
                    ],
                    batch_size: [
                      type: :pos_integer,
                      default: 5,
                      doc: "Number of chunks per LLM batch"
                    ],
                    extraction_passes: [
                      type: :pos_integer,
                      default: 1,
                      doc: "Number of extraction passes for multi-pass extraction"
                    ],
                    max_concurrency: [
                      type: :pos_integer,
                      default: 8,
                      doc: "Maximum concurrent LLM requests"
                    ],
                    temperature: [
                      type: {:custom, __MODULE__, :validate_temperature, []},
                      default: 0.2,
                      doc: "LLM sampling temperature (0.0-1.0)",
                      type_spec: quote(do: float() | nil)
                    ],
                    max_tokens: [
                      type: :pos_integer,
                      default: 4096,
                      doc: "Maximum tokens in LLM response"
                    ],
                    timeout: [
                      type: :pos_integer,
                      default: 60_000,
                      doc: "Request timeout in milliseconds"
                    ],
                    attribute_suffix: [
                      type: :string,
                      default: "_attributes",
                      doc: "Suffix for attribute keys in structured output"
                    ]
                  )

  @typedoc """
  #{NimbleOptions.docs(@options_schema)}
  """
  @type options() :: [unquote(NimbleOptions.option_typespec(@options_schema))]

  @type t :: %__MODULE__{
          prompt: String.t() | nil,
          examples: [map()],
          template_file: String.t() | nil,
          model: String.t() | nil,
          provider: atom() | nil,
          api_key: String.t() | nil,
          format: :json | :yaml,
          fence_output: boolean(),
          use_structured_output: boolean(),
          max_char_buffer: pos_integer(),
          chunk_overlap: non_neg_integer(),
          batch_size: pos_integer(),
          extraction_passes: pos_integer(),
          max_concurrency: pos_integer(),
          temperature: float() | nil,
          max_tokens: pos_integer() | nil,
          timeout: pos_integer(),
          attribute_suffix: String.t()
        }

  defstruct prompt: nil,
            examples: [],
            template_file: nil,
            model: nil,
            provider: nil,
            api_key: nil,
            format: :yaml,
            fence_output: false,
            use_structured_output: false,
            max_char_buffer: 1000,
            chunk_overlap: 200,
            batch_size: 5,
            extraction_passes: 1,
            max_concurrency: 8,
            temperature: 0.2,
            max_tokens: 4096,
            timeout: 60_000,
            attribute_suffix: "_attributes"

  @doc """
  Returns default configuration.

  ## Examples

      iex> config = LeXtract.Config.default()
      iex> config.batch_size
      5

  """
  @spec default() :: t()
  def default, do: %__MODULE__{}

  @doc """
  Creates and validates configuration from keyword list.

  Validates options using NimbleOptions and raises `NimbleOptions.ValidationError` if invalid.

  ## Examples

      iex> config = LeXtract.Config.new(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: 2000)
      iex> config.model
      "gpt-4"

      iex> LeXtract.Config.new(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: -1)
      ** (NimbleOptions.ValidationError) invalid value for :max_char_buffer option: expected positive integer, got: -1

      iex> LeXtract.Config.new(model: "gpt-4", provider: :openai, prompt: "test", temperature: 1.5)
      ** (NimbleOptions.ValidationError) invalid value for :temperature option: must be a float between 0.0 and 1.0, got: 1.5

      iex> LeXtract.Config.new(model: "gpt-4", provider: :openai, prompt: "test", format: :xml)
      ** (NimbleOptions.ValidationError) invalid value for :format option: expected one of [:json, :yaml], got: :xml

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    validated_opts = NimbleOptions.validate!(opts, @options_schema)
    struct!(__MODULE__, validated_opts)
  end

  @doc """
  Converts a keyword list to a Config struct with validation.

  This function is useful for maintaining backward compatibility with
  code that uses keyword lists. It validates the options and returns
  a Config struct.

  ## Examples

      iex> {:ok, config} = LeXtract.Config.from_keyword(model: "gpt-4", provider: :openai, prompt: "test")
      iex> config.model
      "gpt-4"

      iex> {:error, _} = LeXtract.Config.from_keyword(model: "gpt-4")

  """
  @spec from_keyword(keyword()) :: {:ok, t()} | {:error, Exception.t()}
  def from_keyword(opts) when is_list(opts) do
    validate(opts)
  end

  @doc """
  Converts a keyword list to a Config struct, raising on error.

  ## Examples

      iex> config = LeXtract.Config.from_keyword!(model: "gpt-4", provider: :openai, prompt: "test")
      iex> config.model
      "gpt-4"

  """
  @spec from_keyword!(keyword()) :: t()
  def from_keyword!(opts) when is_list(opts) do
    case from_keyword(opts) do
      {:ok, config} -> config
      {:error, error} -> raise error
    end
  end

  @doc """
  Validates configuration keyword list or struct.

  Returns `{:ok, validated_config}` on success or `{:error, validation_error}` on failure.

  ## Examples

      iex> {:ok, config} = LeXtract.Config.validate(max_char_buffer: 1000, model: "gpt-4", provider: :openai, prompt: "test")
      iex> config.max_char_buffer
      1000

      iex> {:error, error} = LeXtract.Config.validate(max_char_buffer: -1, model: "gpt-4", provider: :openai, prompt: "test")
      iex> String.contains?(Exception.message(error), "expected positive integer")
      true

      iex> {:error, error} = LeXtract.Config.validate(temperature: 1.5, model: "gpt-4", provider: :openai, prompt: "test")
      iex> String.contains?(Exception.message(error), "must be a float between 0.0 and 1.0")
      true

  """
  @spec validate(keyword() | t()) :: {:ok, t()} | {:error, Exception.t()}
  def validate(opts) when is_list(opts) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, validated_opts} ->
        validate_template_options(validated_opts)

      {:error, %NimbleOptions.ValidationError{} = error} ->
        {:error, LeXtract.Error.Invalid.Config.exception(errors: Exception.message(error))}
    end
  end

  def validate(%__MODULE__{} = config) do
    opts =
      config
      |> Map.from_struct()
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.into([])

    validate(opts)
  end

  defp validate_template_options(opts) do
    case check_template_configuration(opts) do
      :ok -> {:ok, struct!(__MODULE__, opts)}
      error -> error
    end
  end

  defp check_template_configuration(opts) do
    has_inline = has_inline_template?(opts)
    has_file = has_file_template?(opts)

    cond do
      has_inline and has_file ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors:
             "Cannot specify both inline template options (:prompt, :examples) and :template_file"
         )}

      not has_inline and not has_file ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors:
             "Must specify either inline template options (:prompt with optional :examples) or :template_file"
         )}

      has_inline and is_nil(Keyword.get(opts, :prompt)) ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors: "When using inline template, :prompt is required"
         )}

      true ->
        :ok
    end
  end

  defp has_inline_template?(opts) do
    prompt_value = Keyword.get(opts, :prompt)
    examples_value = Keyword.get(opts, :examples, [])
    not is_nil(prompt_value) or (is_list(examples_value) and examples_value != [])
  end

  defp has_file_template?(opts) do
    not is_nil(Keyword.get(opts, :template_file))
  end

  @doc """
  Validates configuration and raises on error.

  Returns the validated config struct or raises `LeXtract.Error.Invalid.Config`.

  ## Examples

      iex> LeXtract.Config.validate!(max_char_buffer: 1000, model: "gpt-4", provider: :openai, prompt: "test")
      %LeXtract.Config{max_char_buffer: 1000, model: "gpt-4", provider: :openai, prompt: "test"}

      iex> LeXtract.Config.validate!(max_char_buffer: -1, model: "gpt-4", provider: :openai)
      ** (LeXtract.Error.Invalid.Config) Configuration validation failed: invalid value for :max_char_buffer option: expected positive integer, got: -1

  """
  @spec validate!(keyword() | t()) :: t()
  def validate!(opts) do
    case validate(opts) do
      {:ok, config} -> config
      {:error, error} -> raise error
    end
  end

  @doc """
  Converts a Config struct to a keyword list.

  This is useful for backward compatibility when functions expect keyword lists.

  ## Examples

      iex> config = LeXtract.Config.new(model: "gpt-4", provider: :openai, prompt: "test")
      iex> kw = LeXtract.Config.to_keyword(config)
      iex> Keyword.get(kw, :model)
      "gpt-4"

  """
  @spec to_keyword(t()) :: keyword()
  def to_keyword(%__MODULE__{} = config) do
    Map.from_struct(config) |> Map.to_list()
  end
end
