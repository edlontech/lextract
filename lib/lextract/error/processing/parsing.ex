defmodule LeXtract.Error.Processing.Parsing do
  @moduledoc """
  Error for JSON/YAML parsing failures.

  Raised when text cannot be parsed in the expected format.

  ## Examples

      iex> error = LeXtract.Error.Processing.Parsing.exception(
      ...>   format: :json,
      ...>   reason: "unexpected token at position 5"
      ...> )
      iex> String.contains?(Exception.message(error), "JSON")
      true

      iex> error = LeXtract.Error.Processing.Parsing.exception(
      ...>   format: :yaml,
      ...>   reason: "invalid indentation",
      ...>   content_sample: "key:value\\n  bad"
      ...> )
      iex> String.contains?(Exception.message(error), "YAML")
      true

  """

  use Splode.Error,
    fields: [:format, :reason, :content_sample],
    class: :processing

  @type t :: %__MODULE__{
          format: :json | :yaml,
          reason: String.t(),
          content_sample: String.t() | nil
        }

  @doc """
  Formats the error message for parsing failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{format: format, reason: reason, content_sample: nil}) do
    format_name = format_to_string(format)
    "#{format_name} parsing failed: #{reason}"
  end

  def message(%__MODULE__{format: format, reason: reason, content_sample: sample}) do
    format_name = format_to_string(format)
    truncated_sample = String.slice(sample, 0, 100)

    "#{format_name} parsing failed: #{reason}\nContent sample: #{truncated_sample}"
  end

  defp format_to_string(:json), do: "JSON"
  defp format_to_string(:yaml), do: "YAML"
  defp format_to_string(other), do: to_string(other)
end
