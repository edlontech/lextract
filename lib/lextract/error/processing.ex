defmodule LeXtract.Error.Processing do
  @moduledoc """
  Error class for processing pipeline failures.

  Covers errors during text processing, chunking, tokenization,
  alignment, resolution, and other pipeline operations.

  ## Examples

      iex> error = LeXtract.Error.Processing.Parsing.exception(
      ...>   format: :json,
      ...>   reason: "unexpected token"
      ...> )
      iex> match?(%LeXtract.Error.Processing.Parsing{}, error)
      true

  """

  use Splode.ErrorClass, class: :processing
end
