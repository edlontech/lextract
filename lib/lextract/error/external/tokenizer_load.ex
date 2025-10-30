defmodule LeXtract.Error.External.TokenizerLoad do
  @moduledoc """
  Error for tokenizer loading failures.

  Raised when a tokenizer cannot be loaded from Hugging Face or
  when tokenizer initialization fails.

  ## Examples

      iex> error = LeXtract.Error.External.TokenizerLoad.exception(
      ...>   reason: "network timeout"
      ...> )
      iex> Exception.message(error)
      "Failed to load tokenizer: network timeout"

      iex> error = LeXtract.Error.External.TokenizerLoad.exception(
      ...>   reason: "model not found",
      ...>   model_identifier: "invalid-model"
      ...> )
      iex> String.contains?(Exception.message(error), "invalid-model")
      true

  """

  use Splode.Error,
    fields: [:reason, :model_identifier],
    class: :external

  @type t :: %__MODULE__{
          reason: String.t(),
          model_identifier: String.t() | nil
        }

  @doc """
  Formats the error message for tokenizer loading failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: reason, model_identifier: nil}) do
    "Failed to load tokenizer: #{reason}"
  end

  def message(%__MODULE__{reason: reason, model_identifier: model}) do
    "Failed to load tokenizer '#{model}': #{reason}"
  end
end
