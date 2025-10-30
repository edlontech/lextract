defmodule LeXtract.Error.Invalid.Config do
  @moduledoc """
  Error for configuration validation failures.

  Wraps NimbleOptions.ValidationError and provides context about
  which configuration options are invalid.

  ## Examples

      iex> error = LeXtract.Error.Invalid.Config.exception(
      ...>   errors: "invalid value for :max_char_buffer option: expected positive integer, got: -1"
      ...> )
      iex> String.contains?(Exception.message(error), "max_char_buffer")
      true

  """

  use Splode.Error,
    fields: [:errors],
    class: :invalid

  @type t :: %__MODULE__{
          errors: String.t() | [String.t()]
        }

  @doc """
  Formats the error message for configuration validation errors.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{errors: errors}) when is_list(errors) do
    formatted_errors =
      errors
      |> Enum.map(&"  - #{&1}")
      |> Enum.join("\n")

    "Configuration validation failed:\n#{formatted_errors}"
  end

  def message(%__MODULE__{errors: errors}) when is_binary(errors) do
    "Configuration validation failed: #{errors}"
  end

  def message(%__MODULE__{errors: errors}) do
    "Configuration validation failed: #{inspect(errors)}"
  end
end
