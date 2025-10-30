defmodule LeXtract.Error.Processing.Chunking do
  @moduledoc """
  Error for text chunking failures.

  Raised when document chunking fails, typically due to
  tokenization issues or invalid chunk parameters.

  ## Examples

      iex> error = LeXtract.Error.Processing.Chunking.exception(
      ...>   reason: "chunk size must be positive"
      ...> )
      iex> Exception.message(error)
      "Chunking failed: chunk size must be positive"

  """

  use Splode.Error,
    fields: [:reason],
    class: :processing

  @type t :: %__MODULE__{
          reason: String.t()
        }

  @doc """
  Formats the error message for chunking failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: reason}) do
    "Chunking failed: #{reason}"
  end
end
