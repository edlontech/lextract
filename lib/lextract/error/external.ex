defmodule LeXtract.Error.External do
  @moduledoc """
  Error class for external service and resource failures.

  Includes errors from file I/O, API calls, LLM requests,
  tokenizer loading, and other external dependencies.

  ## Examples

      iex> error = LeXtract.Error.External.TemplateRead.exception(
      ...>   path: "/tmp/template.json",
      ...>   reason: :enoent
      ...> )
      iex> match?(%LeXtract.Error.External.TemplateRead{}, error)
      true

  """

  use Splode.ErrorClass, class: :external
end
