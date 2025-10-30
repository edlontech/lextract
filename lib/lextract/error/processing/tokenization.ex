defmodule LeXtract.Error.Processing.Tokenization do
  @moduledoc """
  Error for tokenization failures.

  Raised when text cannot be tokenized, typically due to encoding
  issues or invalid character sequences.

  ## Examples

      iex> error = LeXtract.Error.Processing.Tokenization.exception(
      ...>   reason: "encoding failed"
      ...> )
      iex> Exception.message(error)
      "Tokenization failed: encoding failed"

      iex> error = LeXtract.Error.Processing.Tokenization.exception(
      ...>   reason: "invalid UTF-8 sequence",
      ...>   text_sample: "test \\xFF invalid"
      ...> )
      iex> String.contains?(Exception.message(error), "invalid UTF-8")
      true

  """

  use Splode.Error,
    fields: [:reason, :text_sample],
    class: :processing

  @type t :: %__MODULE__{
          reason: String.t(),
          text_sample: String.t() | nil
        }

  @doc """
  Formats the error message for tokenization failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: reason, text_sample: nil}) do
    "Tokenization failed: #{reason}"
  end

  def message(%__MODULE__{reason: reason, text_sample: sample}) do
    truncated_sample = String.slice(sample, 0, 100)
    "Tokenization failed: #{reason}\nText sample: #{truncated_sample}"
  end
end
