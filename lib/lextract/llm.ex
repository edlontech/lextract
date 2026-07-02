defmodule LeXtract.LLM do
  @moduledoc """
  Behaviour for pluggable LLM adapters.

  Callbacks are thin and per-prompt: the core (`LeXtract.Annotator`) owns
  concurrency via `Task.async_stream/3` and invokes an adapter once per
  prompt. Adapters implement single-shot calls only — no batching, no
  retries, no streaming.

  The `prompt` argument is always a plain `String.t()`, matching the output
  of `LeXtract.Prompting.render/3`. The `schema` argument passed to
  `generate_object/3` is LeXtract's internal keyword representation (as
  produced by `LeXtract.Schema.from_examples/2`); each adapter is
  responsible for translating it into its own provider format.

  `validate_opts/1` is optional. When implemented, it lets an adapter
  validate its own opts (e.g. required credentials, availability of an
  optional dependency) ahead of time, independent of `LeXtract.Config`.

  ## Example

      defmodule MyAdapter do
        @behaviour LeXtract.LLM

        @impl LeXtract.LLM
        def generate_text(prompt, opts), do: {:ok, "..."}

        @impl LeXtract.LLM
        def generate_object(prompt, schema, opts), do: {:ok, %{}}
      end

  """

  @callback generate_text(prompt :: String.t(), opts :: keyword()) ::
              {:ok, String.t()} | {:error, term()}

  @callback generate_object(prompt :: String.t(), schema :: keyword(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback validate_opts(opts :: keyword()) :: {:ok, keyword()} | {:error, term()}

  @optional_callbacks validate_opts: 1
end
