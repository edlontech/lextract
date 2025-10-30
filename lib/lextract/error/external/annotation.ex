defmodule LeXtract.Error.External.Annotation do
  @moduledoc """
  Error for LLM annotation/inference failures.

  Raised when LLM API calls fail, including network errors, rate limits,
  authentication issues, or invalid responses.

  ## Examples

      iex> error = LeXtract.Error.External.Annotation.exception(
      ...>   reason: "API rate limit exceeded"
      ...> )
      iex> Exception.message(error)
      "LLM annotation failed: API rate limit exceeded"

      iex> error = LeXtract.Error.External.Annotation.exception(
      ...>   reason: "request timeout",
      ...>   request_details: %{model: "gemini-2.0-flash", chunk_id: 5}
      ...> )
      iex> String.contains?(Exception.message(error), "gemini-2.0-flash")
      true

  """

  use Splode.Error,
    fields: [:reason, :request_details],
    class: :external

  @type t :: %__MODULE__{
          reason: String.t(),
          request_details: map() | nil
        }

  @doc """
  Formats the error message for LLM annotation failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: reason, request_details: nil}) do
    "LLM annotation failed: #{reason}"
  end

  def message(%__MODULE__{reason: reason, request_details: details}) when is_map(details) do
    details_str =
      details
      |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
      |> Enum.join(", ")

    "LLM annotation failed: #{reason} (#{details_str})"
  end
end
