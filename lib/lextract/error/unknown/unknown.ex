defmodule LeXtract.Error.Unknown.Unknown do
  @moduledoc """
  Catch-all error for truly unexpected failures.

  This error is used when an error doesn't fit any other category
  or when wrapping arbitrary error values.

  ## Examples

      iex> error = LeXtract.Error.Unknown.Unknown.exception(error: "something went wrong")
      iex> Exception.message(error)
      "something went wrong"

      iex> error = LeXtract.Error.Unknown.Unknown.exception(error: %RuntimeError{message: "boom"})
      iex> String.contains?(Exception.message(error), "RuntimeError")
      true

  """

  use Splode.Error,
    fields: [:error],
    class: :unknown

  @type t :: %__MODULE__{
          error: term()
        }

  @doc """
  Formats the error message.

  If the error is a binary string, returns it as-is.
  Otherwise, inspects the error value.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{error: error}) when is_binary(error) do
    error
  end

  def message(%__MODULE__{error: error}) do
    inspect(error)
  end
end
