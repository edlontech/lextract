defmodule LeXtract.LLM.Stub do
  @moduledoc """
  Canned `LeXtract.LLM` adapter for tests.

  Returns configurable responses via `opts`, so annotator tests can drive
  behaviour without mocking `ReqLLM`. `opts[:canned_text]` /
  `opts[:canned_object]` may be a literal value or a 0-arity function for
  tests that need per-call variation, such as call counting or alternating
  responses across passes. `opts[:error]`, when set, forces an
  `{:error, reason}` return from both callbacks.
  """

  @behaviour LeXtract.LLM

  @impl LeXtract.LLM
  def generate_text(_prompt, opts) do
    case Keyword.get(opts, :error) do
      nil -> {:ok, resolve(Keyword.get(opts, :canned_text, ""))}
      reason -> {:error, reason}
    end
  end

  @impl LeXtract.LLM
  def generate_object(_prompt, _schema, opts) do
    case Keyword.get(opts, :error) do
      nil -> {:ok, resolve(Keyword.get(opts, :canned_object, %{"extractions" => []}))}
      reason -> {:error, reason}
    end
  end

  @impl LeXtract.LLM
  def validate_opts(opts), do: {:ok, opts}

  defp resolve(fun) when is_function(fun, 0), do: fun.()
  defp resolve(value), do: value
end
