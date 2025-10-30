defmodule LeXtract.Error do
  @moduledoc """
  Main error aggregator for LeXtract using Splode.

  This module provides structured error handling with four error classes:
  - `:invalid` - Validation and format errors
  - `:processing` - Processing pipeline failures
  - `:external` - External service/resource failures
  - `:unknown` - Unexpected errors

  ## Examples

      iex> error = LeXtract.Error.Invalid.Format.exception(format_string: "xml")
      iex> LeXtract.Error.splode_error?(error)
      true

      iex> errors = [
      ...>   LeXtract.Error.Processing.Parsing.exception(format: :json, reason: "unexpected token"),
      ...>   LeXtract.Error.Invalid.Config.exception(errors: [])
      ...> ]
      iex> class_error = LeXtract.Error.to_class(errors)
      iex> match?(%LeXtract.Error.Invalid{}, class_error)
      true

  """

  use Splode,
    error_classes: [
      invalid: LeXtract.Error.Invalid,
      processing: LeXtract.Error.Processing,
      external: LeXtract.Error.External,
      unknown: LeXtract.Error.Unknown
    ],
    unknown_error: LeXtract.Error.Unknown.Unknown
end
