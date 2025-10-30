defmodule LeXtract.Annotator do
  @moduledoc """
  Annotates documents with extractions using LLMs.

  The core extraction orchestrator that:
  1. Chunks documents
  2. Generates prompts
  3. Calls LLM via ReqLLM
  4. Parses and aligns results
  5. Aggregates into AnnotatedDocument

  ## Examples

      iex> template = %{
      ...>   description: "Extract medication entities",
      ...>   examples: [
      ...>     %{
      ...>       text: "Patient takes aspirin",
      ...>       extractions: [%{medication: "aspirin"}]
      ...>     }
      ...>   ]
      ...> }
      iex> annotator = LeXtract.Annotator.new(template,
      ...>   model: "gemini-2.0-flash",
      ...>   provider: :gemini,
      ...>   api_key: "test-key"
      ...> )
      iex> is_struct(annotator, LeXtract.Annotator)
      true

  """

  require Logger

  alias LeXtract.{
    AnnotatedDocument,
    Alignment,
    CharInterval,
    Chunking,
    Document,
    FormatHandler,
    Prompting,
    Resolver,
    Tokenizer
  }

  @type t :: %__MODULE__{
          prompt_generator: Prompting.t(),
          format_handler: FormatHandler.t(),
          req_llm_config: keyword()
        }

  @enforce_keys [:prompt_generator, :format_handler, :req_llm_config]
  defstruct [:prompt_generator, :format_handler, :req_llm_config]

  @doc """
  Creates a new annotator.

  ## Parameters

    * `prompt_template` - Template with description and examples
    * `req_llm_config` - ReqLLM configuration (model, provider, API keys, etc.)
    * `opts` - Options (see below)

  ## Options

    * `:format` - Output format (:json or :yaml, default: :yaml)
    * `:fence_output` - Whether to expect fenced output (default: false)
    * `:attribute_suffix` - Suffix for attributes (default: "_attributes")

  ## Examples

      iex> template = %{description: "Extract entities", examples: []}
      iex> config = [model: "gemini-2.0-flash", provider: :gemini, api_key: "test"]
      iex> annotator = LeXtract.Annotator.new(template, config)
      iex> annotator.format_handler.format
      :yaml

  """
  @spec new(Prompting.template(), keyword(), keyword()) :: t()
  def new(prompt_template, req_llm_config, opts \\ []) do
    format = Keyword.get(opts, :format, :yaml)
    fence_output = Keyword.get(opts, :fence_output, false)
    attribute_suffix = Keyword.get(opts, :attribute_suffix, "_attributes")

    format_handler =
      FormatHandler.new(format,
        fence_output: fence_output,
        attribute_suffix: attribute_suffix
      )

    prompt_generator = Prompting.new(prompt_template, format_handler, opts)

    %__MODULE__{
      prompt_generator: prompt_generator,
      format_handler: format_handler,
      req_llm_config: req_llm_config
    }
  end

  @doc """
  Annotates a single text string.

  Convenience wrapper around annotate_documents/3 for single text inputs.

  ## Parameters

    * `annotator` - The annotator instance
    * `text` - Text to extract from
    * `opts` - Options (see annotate_documents/3)

  ## Returns

  Single `%AnnotatedDocument{}` with extractions aligned to text.

  ## Examples

      iex> template = %{description: "Extract entities", examples: []}
      iex> annotator = LeXtract.Annotator.new(template,
      ...>   model: "gemini-2.0-flash",
      ...>   provider: :gemini,
      ...>   api_key: "test"
      ...> )
      iex> # Note: This example would require mocking ReqLLM in real tests
      iex> is_struct(annotator, LeXtract.Annotator)
      true

  """
  @spec annotate_text(t(), String.t(), keyword()) :: AnnotatedDocument.t()
  def annotate_text(%__MODULE__{} = annotator, text, opts \\ []) when is_binary(text) do
    doc = Document.create(text)

    result =
      annotator
      |> annotate_documents([doc], opts)
      |> Enum.to_list()
      |> List.first()

    result || AnnotatedDocument.new(text: text, document_id: doc.document_id, extractions: [])
  end

  @doc """
  Annotates a stream of documents.

  Main API for batch processing. Handles:
  - Chunking of long documents
  - Batch inference for efficiency
  - Alignment of extractions
  - Multi-pass extraction (if enabled)

  ## Parameters

    * `annotator` - The annotator instance
    * `documents` - Enumerable of `%Document{}` structs
    * `opts` - Options (see below)

  ## Options

    * `:max_char_buffer` - Max chunk size in chars (default: 1000)
    * `:batch_size` - Number of chunks per LLM batch (default: 5)
    * `:extraction_passes` - Number of passes for multi-pass (default: 1)
    * `:show_progress` - Show progress bar (default: false)
    * `:chunk_overlap` - Chunk overlap in chars (default: 200)

  ## Returns

  Stream of `%AnnotatedDocument{}` with extractions.
  """
  @spec annotate_documents(t(), Enumerable.t(Document.t()), keyword()) ::
          Enumerable.t(AnnotatedDocument.t())
  def annotate_documents(%__MODULE__{} = annotator, documents, opts \\ []) do
    extraction_passes = Keyword.get(opts, :extraction_passes, 1)

    if extraction_passes > 1 do
      annotate_documents_multi_pass(annotator, documents, opts)
    else
      annotate_documents_single_pass(annotator, documents, opts)
    end
  end

  defp annotate_documents_single_pass(annotator, documents, opts) do
    max_char_buffer = Keyword.get(opts, :max_char_buffer, 1000)
    batch_size = Keyword.get(opts, :batch_size, 5)

    documents
    |> Stream.flat_map(fn doc ->
      Chunking.chunk_document(doc,
        max_char_buffer: max_char_buffer,
        chunk_overlap: Keyword.get(opts, :chunk_overlap, 200)
      )
    end)
    |> Stream.chunk_every(batch_size)
    |> Stream.flat_map(fn batch ->
      process_batch(annotator, batch, opts)
    end)
    |> group_chunks_by_document()
  end

  defp group_chunks_by_document(chunk_stream) do
    chunk_stream
    |> Stream.chunk_by(fn {chunk, _extractions} -> chunk.document.document_id end)
    |> Stream.map(fn chunk_group ->
      [{first_chunk, _} | _] = chunk_group

      all_extractions =
        chunk_group
        |> Enum.map(fn {_chunk, extractions} -> extractions end)
        |> List.flatten()

      AnnotatedDocument.new(
        text: first_chunk.document.text,
        document_id: first_chunk.document.document_id,
        extractions: all_extractions
      )
    end)
  end

  defp annotate_documents_multi_pass(annotator, documents, opts) do
    extraction_passes = Keyword.get(opts, :extraction_passes, 2)

    documents
    |> Stream.map(fn doc ->
      passes_for_doc =
        for pass_num <- 1..extraction_passes do
          result =
            annotate_documents_single_pass(
              annotator,
              [doc],
              Keyword.put(opts, :show_progress, pass_num == 1)
            )
            |> Enum.to_list()
            |> List.first()

          result ||
            AnnotatedDocument.new(
              text: doc.text,
              document_id: doc.document_id,
              extractions: []
            )
        end

      first_doc = hd(passes_for_doc)
      all_extractions = Enum.map(passes_for_doc, & &1.extractions)
      merged = merge_non_overlapping_extractions(all_extractions)

      %{first_doc | extractions: merged}
    end)
  end

  defp process_batch(annotator, chunks, _opts) do
    prompts =
      Enum.map(chunks, fn chunk ->
        additional_context =
          if chunk.document do
            chunk.document.additional_context
          else
            nil
          end

        Prompting.render(
          annotator.prompt_generator,
          chunk.text,
          additional_context: additional_context
        )
      end)

    responses = call_req_llm(annotator.req_llm_config, prompts)

    Enum.zip(chunks, responses)
    |> Enum.map(fn
      {chunk, {:ok, response_text}} ->
        extractions =
          case Resolver.resolve(response_text, annotator.format_handler.format) do
            {:ok, exts} ->
              align_extractions_to_chunk(exts, chunk)

            {:error, reason} ->
              Logger.warning("Failed to parse LLM response: #{inspect(reason)}")
              []
          end

        {chunk, extractions}

      {chunk, {:error, reason}} ->
        Logger.warning(
          "Skipping chunk for document #{chunk.document.document_id} due to LLM error: #{inspect(reason)}"
        )

        {chunk, []}
    end)
  end

  defp call_req_llm(req_llm_config, prompts) do
    model = Keyword.fetch!(req_llm_config, :model)
    max_concurrency = Keyword.get(req_llm_config, :max_concurrency, 8)

    prompts
    |> Task.async_stream(
      fn prompt ->
        ReqLLM.generate_text(model, prompt, req_llm_config)
      end,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, {:ok, response}} ->
        {:ok, extract_response_text(response)}

      {:ok, {:error, reason}} ->
        Logger.error("ReqLLM inference failed: #{inspect(reason)}")
        {:error, reason}

      {:exit, reason} ->
        Logger.error("ReqLLM task crashed: #{inspect(reason)}")
        {:error, {:task_exit, reason}}
    end)
  end

  defp extract_response_text(%ReqLLM.Response{message: %{content: content}})
       when is_list(content) do
    content
    |> Enum.filter(fn part -> is_map(part) and Map.has_key?(part, :text) end)
    |> Enum.map_join("\n", fn part -> part.text end)
  end

  defp extract_response_text(%ReqLLM.Response{message: %{content: content}})
       when is_binary(content) do
    content
  end

  defp extract_response_text(%ReqLLM.Response{} = response) do
    Logger.warning("Unexpected ReqLLM response format: #{inspect(response)}")
    ""
  end

  defp extract_response_text(response) do
    Logger.warning("Unexpected response type: #{inspect(response)}")
    ""
  end

  defp align_extractions_to_chunk(extractions, chunk) do
    case Tokenizer.tokenize(chunk.text) do
      {:ok, chunk_encoding} ->
        char_offset = chunk.char_interval.start_pos

        Enum.map(extractions, fn extraction ->
          aligned = Alignment.align_extraction(extraction, chunk_encoding)

          case aligned.char_interval do
            nil ->
              aligned

            interval ->
              adjusted_interval =
                CharInterval.new(
                  interval.start_pos + char_offset,
                  interval.end_pos + char_offset
                )

              %{aligned | char_interval: adjusted_interval}
          end
        end)

      {:error, reason} ->
        Logger.warning("Tokenization failed for chunk: #{inspect(reason)}")
        extractions
    end
  end

  defp merge_non_overlapping_extractions(all_extractions) do
    Enum.reduce(all_extractions, [], fn pass_extractions, acc ->
      Enum.reduce(pass_extractions, acc, fn extraction, acc ->
        if Enum.any?(acc, &extractions_overlap?(&1, extraction)) do
          acc
        else
          [extraction | acc]
        end
      end)
    end)
    |> Enum.reverse()
  end

  defp extractions_overlap?(ext1, ext2) do
    case {ext1.char_interval, ext2.char_interval} do
      {nil, _} -> false
      {_, nil} -> false
      {i1, i2} -> i1.start_pos < i2.end_pos and i2.start_pos < i1.end_pos
    end
  end
end
