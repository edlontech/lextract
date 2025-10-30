defmodule LeXtract.Error.Unknown do
  @moduledoc """
  Error class for unexpected errors.

  A catch-all for errors that don't fit other categories or
  represent truly unexpected system failures.

  ## Examples

      iex> error = LeXtract.Error.Unknown.Unknown.exception(error: "unexpected failure")
      iex> match?(%LeXtract.Error.Unknown.Unknown{}, error)
      true

  """

  use Splode.ErrorClass, class: :unknown
end
