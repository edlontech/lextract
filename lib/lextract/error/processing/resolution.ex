defmodule LeXtract.Error.Processing.Resolution do
  @moduledoc """
  Error for extraction resolution failures.

  Raised when LLM output cannot be resolved into Extraction structs,
  typically due to missing extraction data or malformed response structure.

  ## Examples

      iex> error = LeXtract.Error.Processing.Resolution.exception(
      ...>   reason: "Could not find extractions array in parsed data"
      ...> )
      iex> String.contains?(Exception.message(error), "extractions array")
      true

  """

  use Splode.Error,
    fields: [:reason],
    class: :processing

  @type t :: %__MODULE__{
          reason: String.t()
        }

  @doc """
  Formats the error message for resolution failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: reason}) do
    "Resolution failed: #{reason}"
  end
end
