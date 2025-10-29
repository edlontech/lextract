defmodule LeXtract.Config do
  @moduledoc """
  Configuration for extraction operations using NimbleOptions for validation.

  ## Examples

      iex> config = LeXtract.Config.new(model_id: "gpt-4", max_char_buffer: 2000)
      iex> config.model_id
      "gpt-4"

      iex> config = LeXtract.Config.default()
      iex> config.batch_size
      10

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
                    model_id: [
                      type: :string,
                      default: "gemini-2.0-flash-exp",
                      doc: "LLM model identifier (e.g., 'gemini-2.0-flash-exp', 'gpt-4')"
                    ],
                    api_key: [
                      type: {:or, [:string, nil]},
                      default: nil,
                      doc: "API key for the provider (optional if using environment variables)"
                    ],
                    max_char_buffer: [
                      type: :pos_integer,
                      default: 1000,
                      doc: "Maximum chunk size in characters (must be positive)"
                    ],
                    chunk_overlap: [
                      type: :non_neg_integer,
                      default: 200,
                      doc: "Overlap between chunks in characters (must be non-negative)"
                    ],
                    temperature: [
                      type: {:custom, __MODULE__, :validate_temperature, []},
                      default: nil,
                      doc:
                        "LLM temperature controlling randomness (0.0 - 1.0, or nil for default)",
                      type_spec: quote(do: float() | nil)
                    ],
                    format_type: [
                      type: {:in, [:json, :yaml]},
                      default: :yaml,
                      doc: "Output format type",
                      type_doc: ":json | :yaml"
                    ],
                    use_schema_constraints: [
                      type: :boolean,
                      default: true,
                      doc: "Whether to use schema validation during extraction"
                    ],
                    batch_size: [
                      type: :pos_integer,
                      default: 10,
                      doc: "Number of documents to process per batch"
                    ],
                    max_workers: [
                      type: :pos_integer,
                      default: 10,
                      doc: "Maximum number of concurrent workers"
                    ],
                    timeout: [
                      type: :timeout,
                      default: 60_000,
                      doc: "Request timeout in milliseconds (or :infinity)"
                    ]
                  )

  @type t :: %__MODULE__{
          model_id: String.t(),
          api_key: String.t() | nil,
          max_char_buffer: pos_integer(),
          chunk_overlap: non_neg_integer(),
          temperature: float() | nil,
          format_type: :json | :yaml,
          use_schema_constraints: boolean(),
          batch_size: pos_integer(),
          max_workers: pos_integer(),
          timeout: timeout()
        }

  defstruct model_id: "gemini-2.0-flash-exp",
            api_key: nil,
            max_char_buffer: 1000,
            chunk_overlap: 200,
            temperature: nil,
            format_type: :yaml,
            use_schema_constraints: true,
            batch_size: 10,
            max_workers: 10,
            timeout: 60_000

  @doc """
  Returns default configuration.

  ## Examples

      iex> config = LeXtract.Config.default()
      iex> config.batch_size
      10

  """
  @spec default() :: t()
  def default, do: %__MODULE__{}

  @doc """
  Creates and validates configuration from keyword list.

  Validates options using NimbleOptions and raises `NimbleOptions.ValidationError` if invalid.

  ## Examples

      iex> config = LeXtract.Config.new(model_id: "gpt-4", max_char_buffer: 2000)
      iex> config.model_id
      "gpt-4"

      iex> LeXtract.Config.new(max_char_buffer: -1)
      ** (NimbleOptions.ValidationError) invalid value for :max_char_buffer option: expected positive integer, got: -1

      iex> LeXtract.Config.new(temperature: 1.5)
      ** (NimbleOptions.ValidationError) invalid value for :temperature option: must be a float between 0.0 and 1.0, got: 1.5

      iex> LeXtract.Config.new(format_type: :xml)
      ** (NimbleOptions.ValidationError) invalid value for :format_type option: expected one of [:json, :yaml], got: :xml

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    validated_opts = NimbleOptions.validate!(opts, @options_schema)
    struct!(__MODULE__, validated_opts)
  end

  @doc """
  Validates configuration keyword list or struct.

  Returns `{:ok, validated_config}` on success or `{:error, validation_error}` on failure.

  ## Examples

      iex> LeXtract.Config.validate(max_char_buffer: 1000)
      {:ok, %LeXtract.Config{max_char_buffer: 1000}}

      iex> {:error, error} = LeXtract.Config.validate(max_char_buffer: -1)
      iex> Exception.message(error)
      "invalid value for :max_char_buffer option: expected positive integer, got: -1"

      iex> {:error, error} = LeXtract.Config.validate(temperature: 1.5)
      iex> Exception.message(error)
      "invalid value for :temperature option: must be a float between 0.0 and 1.0, got: 1.5"

  """
  @spec validate(keyword() | t()) :: {:ok, t()} | {:error, NimbleOptions.ValidationError.t()}
  def validate(opts) when is_list(opts) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, validated_opts} -> {:ok, struct!(__MODULE__, validated_opts)}
      {:error, _} = error -> error
    end
  end

  def validate(%__MODULE__{} = config) do
    opts = Map.from_struct(config) |> Map.to_list()
    validate(opts)
  end

  @doc """
  Validates configuration and raises on error.

  Returns the validated config struct or raises `NimbleOptions.ValidationError`.

  ## Examples

      iex> LeXtract.Config.validate!(max_char_buffer: 1000)
      %LeXtract.Config{max_char_buffer: 1000}

      iex> LeXtract.Config.validate!(max_char_buffer: -1)
      ** (NimbleOptions.ValidationError) invalid value for :max_char_buffer option: expected positive integer, got: -1

  """
  @spec validate!(keyword() | t()) :: t()
  def validate!(opts) do
    case validate(opts) do
      {:ok, config} -> config
      {:error, error} -> raise error
    end
  end
end
