defmodule LeXtract.Error.Processing.Alignment do
  @moduledoc """
  Error for text alignment failures.

  Raised when extracted text cannot be aligned back to source text
  positions, typically due to tokenization mismatches or encoding issues.

  ## Examples

      iex> error = LeXtract.Error.Processing.Alignment.exception(
      ...>   reason: "no matching sequence found"
      ...> )
      iex> Exception.message(error)
      "Alignment failed: no matching sequence found"

  """

  use Splode.Error,
    fields: [:reason],
    class: :processing

  @type t :: %__MODULE__{
          reason: String.t()
        }

  @doc """
  Formats the error message for alignment failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: reason}) do
    "Alignment failed: #{reason}"
  end
end
