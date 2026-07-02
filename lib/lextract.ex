defmodule LeXtract do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")

  alias LeXtract.{Annotator, Config, Document, Prompting}

  @legacy_llm_keys [:provider, :model, :api_key, :temperature, :max_tokens, :timeout]
  @default_llm {LeXtract.LLM.ReqLLM, []}

  @doc """
  Extracts structured information from text using LLMs.

  This is the main entry point for the library. It accepts text (string, list of strings,
  or list of Document structs) and returns a lazy Stream of AnnotatedDocument results.

  ## Parameters

  - `input` - Text to extract from (String.t(), [String.t()], or [Document.t()])
  - `opts` - Extraction options (see module documentation for full list)

  ## LLM adapter selection

  The LLM backend is a pluggable `LeXtract.LLM` adapter, resolved in this order:

  1. Per-call `:llm` option — `Module` or `{Module, adapter_opts}`.
  2. `Application.get_env(:lextract, :llm)`, e.g.
     `config :lextract, :llm, {LeXtract.LLM.ReqLLM, provider: :openai, model: "gpt-4o-mini"}`.
  3. Default `{LeXtract.LLM.ReqLLM, []}`.

  Legacy top-level `provider:`/`model:`/`api_key:`/`temperature:`/`max_tokens:`/`timeout:`
  options are still accepted and folded into the resolved adapter's opts when no explicit
  `:llm` option is given, so existing calls keep working unchanged.

  ## Returns

  `{:ok, Stream.t(AnnotatedDocument.t())}` or `{:error, reason}`

  ## Examples

      iex> {:ok, _stream} = LeXtract.extract(
      ...>   "Sample text",
      ...>   prompt: "Extract entities",
      ...>   examples: [],
      ...>   model: "gpt-4o-mini",
      ...>   provider: :openai,
      ...>   api_key: "test-key"
      ...> )
  """
  @spec extract(
          source_document :: String.t() | [String.t()] | [Document.t()],
          options :: Config.options()
        ) :: {:ok, Enumerable.t(LeXtract.AnnotatedDocument.t())} | {:error, Exception.t()}
  def extract(input, opts) when is_list(opts) do
    {adapter_module, adapter_opts, core_opts} = resolve_llm(opts)

    with {:ok, validated_core} <- Config.validate(core_opts),
         {:ok, validated_adapter_opts} <- validate_adapter_opts(adapter_module, adapter_opts),
         validated_opts = Config.to_keyword(validated_core),
         {:ok, template} <- build_template(validated_opts),
         {:ok, documents} <- normalize_input(input),
         {:ok, annotator} <-
           build_annotator(template, {adapter_module, validated_adapter_opts}, validated_opts) do
      stream = Annotator.annotate_documents(annotator, documents, annotator_opts(validated_opts))
      {:ok, stream}
    end
  end

  @doc """
  Extracts structured information from text, raising on error.

  Same as `extract/2` but returns the stream directly or raises an exception on error.

  ## Examples

      iex> stream = LeXtract.extract!(
      ...>   "Sample text",
      ...>   prompt: "Extract entities",
      ...>   examples: [],
      ...>   model: "gpt-4o-mini",
      ...>   provider: :openai,
      ...>   api_key: "test-key"
      ...> )
      iex> is_struct(stream, Stream)
      true

  """
  @spec extract!(
          source_document :: String.t() | [String.t()] | [Document.t()],
          options :: Config.options()
        ) :: Enumerable.t(LeXtract.AnnotatedDocument.t())
  def extract!(input, opts) do
    case extract(input, opts) do
      {:ok, stream} -> stream
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Extracts structured information from a text file.

  Reads the file content and then calls `extract/2`. Useful for processing
  single documents stored on disk.

  ## Parameters

  - `file_path` - Path to text file
  - `opts` - Extraction options (see `extract/2`)

  ## Returns

  `{:ok, Stream.t(AnnotatedDocument.t())}` or `{:error, reason}`

  ## Examples

      iex> File.write!("/tmp/test_doc.txt", "Sample text")
      iex> {:ok, stream} = LeXtract.extract_from_file(
      ...>   "/tmp/test_doc.txt",
      ...>   prompt: "Extract entities",
      ...>   examples: [],
      ...>   model: "gpt-4o-mini",
      ...>   provider: :openai,
      ...>   api_key: "test-key"
      ...> )
      iex> is_struct(stream, Stream)
      true
      iex> File.rm("/tmp/test_doc.txt")
      :ok

  """
  @spec extract_from_file(file_path :: Path.t(), options :: Config.options()) ::
          {:ok, Enumerable.t(LeXtract.AnnotatedDocument.t())} | {:error, Exception.t()}
  def extract_from_file(file_path, opts) do
    case File.read(file_path) do
      {:ok, content} ->
        extract(content, opts)

      {:error, reason} ->
        {:error,
         LeXtract.Error.External.TemplateRead.exception(
           file_path: file_path,
           reason: reason
         )}
    end
  end

  @doc """
  Validates extraction options against the schema.

  Useful for validating options before processing or for debugging configuration issues.
  Validates core options only; LLM adapter options (e.g. `:provider`, `:model`) are
  resolved and validated separately by `extract/2` (see the `:llm` option and the
  legacy compat shim in the module documentation).

  ## Parameters

  - `opts` - Keyword list of options

  ## Returns

  `{:ok, validated_opts}` or `{:error, validation_error}`

  ## Examples

      iex> {:ok, opts} = LeXtract.validate_options(prompt: "Extract")
      iex> Keyword.get(opts, :prompt)
      "Extract"
      iex> Keyword.get(opts, :format)
      :yaml

  """
  @spec validate_options(Config.options()) :: {:ok, Config.options()} | {:error, Exception.t()}
  def validate_options(opts) do
    case Config.validate(opts) do
      {:ok, config} -> {:ok, Config.to_keyword(config)}
      {:error, _} = error -> error
    end
  end

  defp build_template(opts) do
    template_file = Keyword.get(opts, :template_file)
    prompt = Keyword.get(opts, :prompt)

    cond do
      not is_nil(template_file) ->
        read_template_file(opts)

      not is_nil(prompt) ->
        build_inline_template(opts)

      true ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(errors: "No template configuration provided")}
    end
  end

  defp read_template_file(opts) do
    file_path = Keyword.fetch!(opts, :template_file)
    format = determine_template_format(file_path)
    Prompting.read_template(file_path, format)
  end

  defp determine_template_format(file_path) do
    case Path.extname(file_path) do
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      _ -> :yaml
    end
  end

  defp build_inline_template(opts) do
    prompt = Keyword.fetch!(opts, :prompt)
    examples = Keyword.get(opts, :examples, [])

    {:ok,
     %{
       description: prompt,
       examples: normalize_examples(examples)
     }}
  end

  defp normalize_examples(examples) when is_list(examples) do
    Enum.map(examples, fn example ->
      %{
        text: Map.get(example, :text) || Map.get(example, "text") || "",
        extractions: Map.get(example, :extractions) || Map.get(example, "extractions") || []
      }
    end)
  end

  defp normalize_input(text) when is_binary(text) do
    {:ok, [Document.create(text)]}
  end

  defp normalize_input(texts) when is_list(texts) do
    documents =
      Enum.map(texts, fn
        %Document{} = doc -> doc
        text when is_binary(text) -> Document.create(text)
      end)

    {:ok, documents}
  end

  defp resolve_llm(opts) do
    core_opts = strip_llm_opts(opts)

    case Keyword.fetch(opts, :llm) do
      {:ok, llm_spec} ->
        {adapter_module, adapter_opts} = normalize_llm_spec(llm_spec)
        {adapter_module, adapter_opts, core_opts}

      :error ->
        {adapter_module, base_adapter_opts} =
          normalize_llm_spec(Application.get_env(:lextract, :llm, @default_llm))

        legacy_opts = Keyword.take(opts, @legacy_llm_keys)
        adapter_opts = Keyword.merge(base_adapter_opts, legacy_opts)
        {adapter_module, adapter_opts, core_opts}
    end
  end

  defp strip_llm_opts(opts), do: Keyword.drop(opts, [:llm | @legacy_llm_keys])

  defp normalize_llm_spec({module, adapter_opts})
       when is_atom(module) and is_list(adapter_opts),
       do: {module, adapter_opts}

  defp normalize_llm_spec(module) when is_atom(module), do: {module, []}

  defp validate_adapter_opts(adapter_module, adapter_opts) do
    case Code.ensure_loaded(adapter_module) do
      {:module, _} ->
        if function_exported?(adapter_module, :validate_opts, 1) do
          adapter_module.validate_opts(adapter_opts)
        else
          {:ok, adapter_opts}
        end

      {:error, _reason} ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors:
             "LLM adapter #{inspect(adapter_module)} is not available; " <>
               "add its dependency (e.g. req_llm) or configure a different :llm adapter"
         )}
    end
  end

  defp build_annotator(template, {adapter_module, adapter_opts}, opts) do
    annotator_opts = build_annotator_opts(opts)
    annotator = Annotator.new(template, {adapter_module, adapter_opts}, annotator_opts)

    {:ok, annotator}
  end

  defp build_annotator_opts(opts) do
    [
      format: Keyword.get(opts, :format, :yaml),
      fence_output: Keyword.get(opts, :fence_output, false),
      use_structured_output: Keyword.get(opts, :use_structured_output, false),
      attribute_suffix: Keyword.get(opts, :attribute_suffix, "_attributes"),
      max_concurrency: Keyword.get(opts, :max_concurrency, 8)
    ]
  end

  defp annotator_opts(opts) do
    [
      max_char_buffer: Keyword.get(opts, :max_char_buffer, 1000),
      chunk_overlap: Keyword.get(opts, :chunk_overlap, 200),
      batch_size: Keyword.get(opts, :batch_size, 5),
      extraction_passes: Keyword.get(opts, :extraction_passes, 1)
    ]
  end
end
