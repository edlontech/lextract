defmodule LeXtract.Annotator do
  @moduledoc """
  Annotates documents with extractions using LLMs.

  The core extraction orchestrator that:
  1. Chunks documents
  2. Generates prompts
  3. Calls LLM via ReqLLM
  4. Parses and aligns results
  5. Aggregates into AnnotatedDocument

  ## Extraction Modes

  The Annotator supports two modes of operation:

  ### Text Generation Mode (Default)

  Uses `ReqLLM.generate_text/3` to generate free-form text responses in JSON or YAML
  format. The LLM response is parsed and converted to extractions.

      template = %{
        description: "Extract medication entities",
        examples: [
          %{
            text: "Patient takes aspirin 100mg",
            extractions: [
              %{extraction_class: "Medication", name: "aspirin", dosage: "100mg"}
            ]
          }
        ]
      }

      annotator = LeXtract.Annotator.new(template,
        model: "gemini-2.0-flash",
        provider: :gemini,
        api_key: "your-api-key"
      )

      doc = LeXtract.Annotator.annotate_text(annotator, "Patient takes aspirin 100mg daily")

  ### Structured Output Mode

  Uses `ReqLLM.generate_object/4` to generate structured output with schema validation.
  This mode automatically generates a schema from your examples and ensures the LLM
  response conforms to the expected structure.

  Enable with `:use_structured_output` option:

      template = %{
        description: "Extract medication entities with structured output",
        examples: [
          %{
            text: "Patient takes aspirin 100mg twice daily",
            extractions: [
              %{
                extraction_class: "Medication",
                name: "aspirin",
                dosage: "100mg",
                frequency: "twice daily"
              }
            ]
          }
        ]
      }

      annotator = LeXtract.Annotator.new(template,
        [model: "gemini-2.0-flash", provider: :gemini, api_key: "your-api-key"],
        use_structured_output: true
      )

      doc = LeXtract.Annotator.annotate_text(annotator, "Patient takes aspirin 100mg twice daily")

  Structured output mode offers several benefits:
  - Automatic schema generation from examples
  - Built-in validation by the LLM provider
  - More reliable parsing (no JSON/YAML parsing errors)
  - Better support for complex nested structures

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
    ExampleData,
    Extraction,
    FormatHandler,
    Prompting,
    Resolver,
    Schema,
    Tokenizer
  }

  @type t :: %__MODULE__{
          prompt_generator: Prompting.t(),
          format_handler: FormatHandler.t(),
          req_llm_config: keyword(),
          use_structured_output: boolean()
        }

  @enforce_keys [:prompt_generator, :format_handler, :req_llm_config, :use_structured_output]
  defstruct [:prompt_generator, :format_handler, :req_llm_config, :use_structured_output]

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
    * `:use_structured_output` - Use ReqLLM's generate_object/4 for structured output (default: false)

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
    use_structured_output = Keyword.get(opts, :use_structured_output, false)

    format_handler =
      FormatHandler.new(format,
        fence_output: fence_output,
        attribute_suffix: attribute_suffix
      )

    prompt_generator = Prompting.new(prompt_template, format_handler, opts)

    %__MODULE__{
      prompt_generator: prompt_generator,
      format_handler: format_handler,
      req_llm_config: req_llm_config,
      use_structured_output: use_structured_output
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
    responses =
      if annotator.use_structured_output do
        prompts = generate_prompts_for_chunks_structured(chunks, annotator.prompt_generator)

        schema =
          generate_schema_from_examples(annotator.prompt_generator, annotator.format_handler)

        call_req_llm_object(annotator.req_llm_config, prompts, schema)
      else
        prompts = generate_prompts_for_chunks(chunks, annotator.prompt_generator)
        call_req_llm_text(annotator.req_llm_config, prompts)
      end

    Enum.zip(chunks, responses)
    |> Enum.map(fn
      {chunk, {:ok, response_data}} ->
        extractions = process_response(annotator, response_data, chunk)
        {chunk, extractions}

      {chunk, {:error, reason}} ->
        Logger.warning(
          "Skipping chunk for document #{chunk.document.document_id} due to LLM error: #{inspect(reason)}"
        )

        {chunk, []}
    end)
  end

  defp generate_prompts_for_chunks(chunks, prompt_generator) do
    Enum.map(chunks, fn chunk ->
      additional_context =
        if chunk.document do
          chunk.document.additional_context
        else
          nil
        end

      Prompting.render(
        prompt_generator,
        chunk.text,
        additional_context: additional_context
      )
    end)
  end

  defp generate_prompts_for_chunks_structured(chunks, prompt_generator) do
    Enum.map(chunks, fn chunk ->
      additional_context =
        if chunk.document do
          chunk.document.additional_context
        else
          nil
        end

      description = prompt_generator.template.description

      description_with_context =
        if additional_context do
          "#{description}\n\n#{additional_context}"
        else
          description
        end

      "#{description_with_context}\n\n#{chunk.text}"
    end)
  end

  defp process_response(%{use_structured_output: true}, object, chunk) do
    parse_structured_response(object, chunk)
  end

  defp process_response(annotator, response_text, chunk) do
    case Resolver.resolve(response_text, annotator.format_handler.format) do
      {:ok, exts} ->
        align_extractions_to_chunk(exts, chunk)

      {:error, reason} ->
        Logger.warning("Failed to parse LLM response: #{inspect(reason)}")
        []
    end
  end

  defp call_req_llm_text(req_llm_config, prompts) do
    model = Keyword.fetch!(req_llm_config, :model)
    max_concurrency = Keyword.get(req_llm_config, :max_concurrency, 8)
    llm_opts = Keyword.drop(req_llm_config, [:model, :max_concurrency, :api_key, :provider])

    prompts
    |> Task.async_stream(
      fn prompt ->
        ReqLLM.generate_text(model, prompt, llm_opts)
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

  defp call_req_llm_object(req_llm_config, prompts, schema) do
    model = Keyword.fetch!(req_llm_config, :model)
    provider = Keyword.get(req_llm_config, :provider)
    max_concurrency = Keyword.get(req_llm_config, :max_concurrency, 8)
    llm_opts = Keyword.drop(req_llm_config, [:model, :max_concurrency, :api_key, :provider])

    final_schema =
      if provider == :openai do
        build_openai_strict_json_schema(schema)
      else
        schema
      end

    prompts
    |> Task.async_stream(
      fn prompt ->
        ReqLLM.generate_object(model, prompt, final_schema, llm_opts)
      end,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, {:ok, response}} ->
        {:ok, extract_response_object(response)}

      {:ok, {:error, reason}} ->
        Logger.error("ReqLLM structured inference failed: #{inspect(reason)}")
        {:error, reason}

      {:exit, reason} ->
        Logger.error("ReqLLM task crashed: #{inspect(reason)}")
        {:error, {:task_exit, reason}}
    end)
  end

  defp build_openai_strict_json_schema(schema) when is_list(schema) do
    extractions_spec = Keyword.get(schema, :extractions, [])
    keys = Keyword.get(extractions_spec, :keys, [])

    properties =
      Enum.into(keys, %{}, fn {key, opts} ->
        {to_string(key), build_property_schema(opts)}
      end)

    required_keys = Map.keys(properties)

    items_schema = %{
      "type" => "object",
      "properties" => properties,
      "required" => required_keys,
      "additionalProperties" => false
    }

    %{
      "type" => "object",
      "properties" => %{
        "extractions" => %{
          "type" => "array",
          "items" => items_schema,
          "description" => Keyword.get(extractions_spec, :doc, "List of extracted entities")
        }
      },
      "required" => ["extractions"],
      "additionalProperties" => false
    }
  end

  defp build_property_schema(opts) do
    base =
      case Keyword.get(opts, :type, :string) do
        :string ->
          %{"type" => "string"}

        :integer ->
          %{"type" => "integer"}

        :map ->
          %{
            "type" => "object",
            "properties" => %{},
            "required" => [],
            "additionalProperties" => false
          }

        _ ->
          %{"type" => "string"}
      end

    case Keyword.get(opts, :doc) do
      nil -> base
      doc -> Map.put(base, "description", doc)
    end
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
        Enum.map(extractions, &align_and_adjust_extraction(&1, chunk_encoding, char_offset))

      {:error, reason} ->
        Logger.warning("Tokenization failed for chunk: #{inspect(reason)}")
        extractions
    end
  end

  defp align_and_adjust_extraction(extraction, chunk_encoding, char_offset) do
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
  end

  defp merge_non_overlapping_extractions(all_extractions) do
    Enum.reduce(all_extractions, [], fn pass_extractions, acc ->
      Enum.reduce(pass_extractions, acc, &add_if_not_overlapping/2)
    end)
    |> Enum.reverse()
  end

  defp add_if_not_overlapping(extraction, acc) do
    if Enum.any?(acc, &extractions_overlap?(&1, extraction)) do
      acc
    else
      [extraction | acc]
    end
  end

  defp extractions_overlap?(ext1, ext2) do
    case {ext1.char_interval, ext2.char_interval} do
      {nil, _} -> false
      {_, nil} -> false
      {i1, i2} -> i1.start_pos < i2.end_pos and i2.start_pos < i1.end_pos
    end
  end

  defp generate_schema_from_examples(prompt_generator, format_handler) do
    examples =
      Enum.map(prompt_generator.template.examples, fn example ->
        output_map =
          case convert_example_to_schema_format(example.extractions, format_handler) do
            [] -> %{"extractions" => []}
            extractions -> %{"extractions" => extractions}
          end

        %ExampleData{
          input: example.text,
          output: output_map
        }
      end)

    Schema.from_examples(examples)
  end

  defp convert_example_to_schema_format(extractions, format_handler) do
    Enum.map(extractions, fn extraction ->
      class = Map.get(extraction, :extraction_class) || Map.get(extraction, "extraction_class")

      attribute_key =
        class
        |> Macro.underscore()
        |> Kernel.<>(format_handler.attribute_suffix)

      attributes =
        extraction
        |> Map.drop([:extraction_class, "extraction_class", :extraction_text, "extraction_text"])
        |> Enum.map(fn {k, v} -> {to_string(k), v} end)
        |> Enum.into(%{})

      base_map = %{"class" => class}

      if map_size(attributes) > 0 do
        Map.put(base_map, attribute_key, attributes)
      else
        base_map
      end
    end)
  end

  defp extract_response_object(%ReqLLM.Response{object: object}) when is_map(object) do
    object
  end

  defp extract_response_object(%ReqLLM.Response{} = response) do
    Logger.warning("Unexpected ReqLLM response format for object: #{inspect(response)}")
    %{"extractions" => []}
  end

  defp extract_response_object(response) do
    Logger.warning("Unexpected response type for object: #{inspect(response)}")
    %{"extractions" => []}
  end

  defp parse_structured_response(object, chunk) do
    extractions = Map.get(object, "extractions", []) || Map.get(object, :extractions, [])

    extraction_structs =
      Enum.map(extractions, fn extraction_data ->
        convert_object_to_extraction(extraction_data)
      end)

    align_extractions_to_chunk(extraction_structs, chunk)
  end

  defp convert_object_to_extraction(extraction_data) when is_map(extraction_data) do
    class = Map.get(extraction_data, "class") || Map.get(extraction_data, :class)

    attributes =
      extraction_data
      |> Enum.filter(fn {key, _value} ->
        key_str = to_string(key)
        String.ends_with?(key_str, "_attributes")
      end)
      |> Enum.flat_map(fn {_key, attrs} ->
        if is_map(attrs), do: Map.to_list(attrs), else: []
      end)
      |> Enum.into(%{})

    extraction_text =
      Map.get(attributes, "name") ||
        Map.get(attributes, :name) ||
        Map.get(attributes, "text") ||
        Map.get(attributes, :text) ||
        Map.get(attributes, "extraction_text") ||
        Map.get(attributes, :extraction_text)

    attributes_without_text =
      if map_size(attributes) > 0 do
        attributes
        |> Map.drop(["name", :name, "text", :text, "extraction_text", :extraction_text])
      else
        nil
      end

    %Extraction{
      extraction_class: class,
      extraction_text: extraction_text,
      attributes: attributes_without_text
    }
  end
end
