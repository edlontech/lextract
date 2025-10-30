defmodule LeXtract.Error.Invalid.Format do
  @moduledoc """
  Error for unknown or invalid format types.

  Raised when a format string doesn't match supported formats (json, yaml).

  ## Examples

      iex> error = LeXtract.Error.Invalid.Format.exception(format_string: "xml")
      iex> Exception.message(error)
      "Unknown format type: xml"

      iex> error = LeXtract.Error.Invalid.Format.exception(
      ...>   format_string: "xml",
      ...>   reason: "Only JSON and YAML are supported"
      ...> )
      iex> String.contains?(Exception.message(error), "Only JSON and YAML")
      true

  """

  use Splode.Error,
    fields: [:format_string, :reason],
    class: :invalid

  @type t :: %__MODULE__{
          format_string: String.t(),
          reason: String.t() | nil
        }

  @doc """
  Formats the error message for format type errors.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{format_string: format_string, reason: nil}) do
    "Unknown format type: #{format_string}"
  end

  def message(%__MODULE__{format_string: format_string, reason: reason}) do
    "Unknown format type: #{format_string}. #{reason}"
  end
end
