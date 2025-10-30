defmodule LeXtract do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")

  alias LeXtract.{Annotator, Config, Document, Prompting}

  @doc """
  Extracts structured information from text using LLMs.

  This is the main entry point for the library. It accepts text (string, list of strings,
  or list of Document structs) and returns a lazy Stream of AnnotatedDocument results.

  ## Parameters

  - `input` - Text to extract from (String.t(), [String.t()], or [Document.t()])
  - `opts` - Extraction options (see module documentation for full list)

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
    with {:ok, validated_opts} <- validate_options(opts),
         {:ok, template} <- build_template(validated_opts),
         {:ok, documents} <- normalize_input(input),
         {:ok, annotator} <- build_annotator(template, validated_opts) do
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

  ## Parameters

  - `opts` - Keyword list of options

  ## Returns

  `{:ok, validated_opts}` or `{:error, validation_error}`

  ## Examples

      iex> {:ok, opts} = LeXtract.validate_options(
      ...>   prompt: "Extract",
      ...>   model: "gpt-4o-mini",
      ...>   provider: :openai,
      ...>   api_key: "key"
      ...> )
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

  defp build_annotator(template, opts) do
    req_llm_config = build_req_llm_config(opts)
    annotator_opts = build_annotator_opts(opts)
    annotator = Annotator.new(template, req_llm_config, annotator_opts)

    {:ok, annotator}
  end

  defp build_req_llm_config(opts) do
    provider = Keyword.fetch!(opts, :provider)
    model = Keyword.fetch!(opts, :model)

    base_config = [
      model: "#{provider}:#{model}",
      provider: provider,
      api_key: Keyword.get(opts, :api_key),
      max_concurrency: Keyword.get(opts, :max_concurrency, 8)
    ]

    config =
      base_config
      |> maybe_add(:temperature, opts)
      |> maybe_add(:max_tokens, opts)

    case Keyword.fetch(opts, :timeout) do
      {:ok, timeout} -> Keyword.put(config, :receive_timeout, timeout)
      :error -> config
    end
  end

  defp build_annotator_opts(opts) do
    [
      format: Keyword.get(opts, :format, :yaml),
      fence_output: Keyword.get(opts, :fence_output, false),
      use_structured_output: Keyword.get(opts, :use_structured_output, false),
      attribute_suffix: Keyword.get(opts, :attribute_suffix, "_attributes")
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

  defp maybe_add(config, key, opts) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> Keyword.put(config, key, value)
      :error -> config
    end
  end
end
