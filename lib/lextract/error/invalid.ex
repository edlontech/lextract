defmodule LeXtract.Error.Invalid do
  @moduledoc """
  Error class for validation and format errors.

  Encompasses all errors related to invalid input, malformed data,
  incorrect formats, and configuration validation failures.

  ## Examples

      iex> error = LeXtract.Error.Invalid.Format.exception(format_string: "xml")
      iex> match?(%LeXtract.Error.Invalid.Format{}, error)
      true

  """

  use Splode.ErrorClass, class: :invalid
end
