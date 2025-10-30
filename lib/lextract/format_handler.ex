defmodule LeXtract.FormatHandler do
  @moduledoc """
  Handles detection and parsing of different text formats (JSON, YAML).

  Supports both fenced and unfenced formats:
  - Fenced: \\`\\`\\`json ... \\`\\`\\`
  - Unfenced: Direct JSON/YAML text

  ## Examples

      iex> json = ~s({"key": "value"})
      iex> LeXtract.FormatHandler.parse(json, :json)
      {:ok, %{"key" => "value"}}

      iex> yaml = "key: value"
      iex> LeXtract.FormatHandler.parse(yaml, :yaml)
      {:ok, %{"key" => "value"}}

  """

  @type format :: :json | :yaml
  @type parse_result :: {:ok, term()} | {:error, String.t()}

  @type t :: %__MODULE__{
          format: format(),
          fence_output: boolean(),
          attribute_suffix: String.t()
        }

  defstruct format: :yaml,
            fence_output: false,
            attribute_suffix: "_attributes"

  @doc """
  Creates a new format handler.

  ## Parameters

    * `format` - Format type (:json or :yaml)
    * `opts` - Options

  ## Options

    * `:fence_output` - Whether output should be fenced (default: false)
    * `:attribute_suffix` - Suffix for attribute fields (default: "_attributes")

  ## Examples

      iex> handler = LeXtract.FormatHandler.new(:json)
      iex> handler.format
      :json

      iex> handler = LeXtract.FormatHandler.new(:yaml, fence_output: true)
      iex> handler.fence_output
      true

  """
  @spec new(format(), keyword()) :: t()
  def new(format, opts \\ []) when format in [:json, :yaml] do
    %__MODULE__{
      format: format,
      fence_output: Keyword.get(opts, :fence_output, false),
      attribute_suffix: Keyword.get(opts, :attribute_suffix, "_attributes")
    }
  end

  @doc """
  Parses text in the specified format.

  Automatically detects and removes code fences if present.

  ## Examples

      iex> json = ~s({"name": "John"})
      iex> {:ok, data} = LeXtract.FormatHandler.parse(json, :json)
      iex> data["name"]
      "John"

      iex> fenced_json = \"\"\"
      ...> ```json
      ...> {"value": 42}
      ...> ```
      ...> \"\"\"
      iex> {:ok, data} = LeXtract.FormatHandler.parse(fenced_json, :json)
      iex> data["value"]
      42

  """
  @spec parse(String.t(), format()) :: parse_result()
  def parse(text, format) do
    text
    |> extract_fenced_content(format)
    |> parse_content(format)
  end

  @doc """
  Detects if text contains code fences for the given format.

  ## Examples

      iex> LeXtract.FormatHandler.fenced?(~s(```json\\n{}\\n```), :json)
      true

      iex> LeXtract.FormatHandler.fenced?(~s({}), :json)
      false

      iex> LeXtract.FormatHandler.fenced?(~s(```yaml\\nkey: value\\n```), :yaml)
      true

      iex> LeXtract.FormatHandler.fenced?(~s(```yml\\nkey: value\\n```), :yaml)
      true

  """
  @spec fenced?(String.t(), format()) :: boolean()
  def fenced?(text, format) do
    fence_pattern = fence_regex(format)
    Regex.match?(fence_pattern, text)
  end

  @doc """
  Extracts content from code fences if present, otherwise returns text unchanged.

  ## Examples

      iex> fenced = ~s(```json\\n{"key": "value"}\\n```)
      iex> LeXtract.FormatHandler.extract_fenced_content(fenced, :json)
      ~s({"key": "value"})

      iex> unfenced = ~s({"key": "value"})
      iex> LeXtract.FormatHandler.extract_fenced_content(unfenced, :json)
      ~s({"key": "value"})

      iex> fenced_yaml = ~s(```yaml\\nkey: value\\n```)
      iex> LeXtract.FormatHandler.extract_fenced_content(fenced_yaml, :yaml)
      "key: value"

  """
  @spec extract_fenced_content(String.t(), format()) :: String.t()
  def extract_fenced_content(text, format) do
    fence_pattern = fence_regex(format)

    case Regex.run(fence_pattern, text, capture: :all_but_first) do
      [content] -> String.trim(content)
      nil -> text
    end
  end

  @doc """
  Validates that text is parseable in the given format.

  ## Examples

      iex> LeXtract.FormatHandler.valid?(~s({"key": "value"}), :json)
      true

      iex> LeXtract.FormatHandler.valid?("{invalid json}", :json)
      false

      iex> LeXtract.FormatHandler.valid?("key: value", :yaml)
      true

  """
  @spec valid?(String.t(), format()) :: boolean()
  def valid?(text, format) do
    case parse(text, format) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp parse_content(text, :json) do
    case Jason.decode(text) do
      {:ok, data} -> {:ok, data}
      {:error, error} -> {:error, "JSON parsing failed: #{inspect(error)}"}
    end
  end

  defp parse_content(text, :yaml) do
    case YamlElixir.read_from_string(text) do
      {:ok, data} -> {:ok, data}
      {:error, error} -> {:error, "YAML parsing failed: #{inspect(error)}"}
    end
  end

  defp fence_regex(:json) do
    ~r/```json\s*\n(.*?)\n```/s
  end

  defp fence_regex(:yaml) do
    ~r/```ya?ml\s*\n(.*?)\n```/s
  end
end
