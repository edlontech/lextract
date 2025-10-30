defmodule LeXtract do
  @moduledoc """
  LeXtract - LLM-powered text extraction library for Elixir.

  LeXtract enables you to extract structured information from unstructured text
  using Large Language Models (LLMs). It provides a simple, streaming API with
  support for multiple LLM providers via ReqLLM.

  ## Features

  - Extract structured entities from text using LLM inference
  - Support for multiple LLM providers (OpenAI, Gemini, Anthropic, etc.)
  - Streaming results for memory-efficient batch processing
  - Automatic text chunking for long documents
  - Character-level alignment of extractions to source text
  - Schema generation from examples
  - Template-based extraction configuration
  - Support for JSON and YAML output formats
  - Multi-pass extraction for improved recall

  ## Installation

  Add `lextract` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [
      {:lextract, "~> 0.1.0"}
    ]
  end
  ```

  ## Quick Start

  ### Basic Entity Extraction

  Extract named entities from text with inline template options:

  ```elixir
  {:ok, stream} = LeXtract.extract(
    "Dr. Smith prescribed aspirin 100mg to the patient.",
    prompt: "Extract medical entities from the text",
    examples: [
      %{
        text: "Patient takes ibuprofen 200mg",
        extractions: [
          %{extraction_class: "Medication", name: "ibuprofen", dosage: "200mg"}
        ]
      }
    ],
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY")
  )

  annotated_docs = Enum.to_list(stream)
  ```

  ### Using Template Files

  Create a template file (JSON or YAML) for reusable extraction configurations:

  ```yaml
  # medication_template.yaml
  description: Extract medication entities with dosage and frequency
  examples:
    - text: "Patient takes aspirin 100mg twice daily"
      extractions:
        - extraction_class: Medication
          name: aspirin
          dosage: 100mg
          frequency: twice daily
  ```

  Then extract using the template:

  ```elixir
  {:ok, stream} = LeXtract.extract(
    "Dr. Jones prescribed metformin 500mg once daily.",
    template_file: "medication_template.yaml",
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY")
  )
  ```

  ### Batch Processing with Streams

  Process multiple documents efficiently with streaming:

  ```elixir
  documents = [
    "First patient document...",
    "Second patient document...",
    "Third patient document..."
  ]

  {:ok, stream} = LeXtract.extract(
    documents,
    prompt: "Extract medical conditions",
    examples: [...],
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY"),
    batch_size: 5
  )

  stream
  |> Stream.each(fn annotated_doc ->
    IO.puts("Document: \#{annotated_doc.document_id}")
    IO.puts("Extractions: \#{length(annotated_doc.extractions)}")
  end)
  |> Stream.run()
  ```

  ### Structured Output Mode

  For better reliability and schema validation, use structured output mode:

  ```elixir
  {:ok, stream} = LeXtract.extract(
    "Patient has hypertension and diabetes.",
    prompt: "Extract medical conditions",
    examples: [
      %{
        text: "Patient diagnosed with asthma",
        extractions: [
          %{extraction_class: "Condition", name: "asthma", severity: "mild"}
        ]
      }
    ],
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY"),
    use_structured_output: true
  )
  ```

  ## Options

  The `extract/2` function accepts the following options:

  ### Template Configuration (choose one approach)

  - `:prompt` - Extraction prompt/description (string)
  - `:examples` - List of example extractions (list of maps)
  - `:template_file` - Path to template file (string, .json or .yaml)

  ### LLM Configuration

  - `:model` - LLM model identifier (required, string, e.g., "gpt-4o-mini")
  - `:provider` - LLM provider (required, atom, e.g., :openai, :gemini)
  - `:api_key` - API key for the provider (required, string)
  - `:temperature` - Sampling temperature (float, 0.0-1.0, default: 0.0)
  - `:max_tokens` - Maximum tokens in response (integer, optional)
  - `:timeout` - Request timeout in milliseconds (integer, default: 60000)

  ### Extraction Configuration

  - `:format` - Output format (atom, :json or :yaml, default: :yaml)
  - `:fence_output` - Expect fenced code blocks (boolean, default: false)
  - `:use_structured_output` - Use structured output mode (boolean, default: false)
  - `:max_char_buffer` - Max chunk size in characters (integer, default: 1000)
  - `:chunk_overlap` - Chunk overlap in characters (integer, default: 200)
  - `:batch_size` - Documents per batch (integer, default: 5)
  - `:extraction_passes` - Number of extraction passes (integer, default: 1)
  - `:max_concurrency` - Max concurrent LLM requests (integer, default: 8)

  ## Return Values

  Returns `{:ok, stream}` where `stream` is a lazy `Stream` of `%LeXtract.AnnotatedDocument{}`
  structs, or `{:error, reason}` if validation or configuration fails.

  Each `AnnotatedDocument` contains:
  - `:text` - Original document text
  - `:document_id` - Unique document identifier
  - `:extractions` - List of `%LeXtract.Extraction{}` structs
  - `:metadata` - Optional metadata

  Each `Extraction` contains:
  - `:extraction_class` - Entity class/type
  - `:extraction_text` - Extracted text span
  - `:char_interval` - Character position in source text
  - `:attributes` - Additional extracted attributes

  ## Examples

  ### Multi-class Entity Extraction

  ```elixir
  {:ok, stream} = LeXtract.extract(
    "John Smith visited Dr. Jane Doe at Memorial Hospital on 2024-01-15.",
    prompt: "Extract people, locations, and dates",
    examples: [
      %{
        text: "Mary went to Boston General on May 1st",
        extractions: [
          %{extraction_class: "Person", name: "Mary"},
          %{extraction_class: "Location", name: "Boston General"},
          %{extraction_class: "Date", value: "May 1st"}
        ]
      }
    ],
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY")
  )
  ```

  ### Reading from Files

  ```elixir
  {:ok, stream} = LeXtract.extract_from_file(
    "document.txt",
    template_file: "extraction_template.yaml",
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY")
  )
  ```

  ### Using Bang Version

  ```elixir
  stream = LeXtract.extract!(
    "Extract from this text",
    prompt: "Extract entities",
    examples: [...],
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY")
  )
  ```

  ## Error Handling

  The library uses `{:ok, result}` / `{:error, reason}` tuples for error handling.
  Errors are structured using the `Splode` library and include detailed context.

  Common error types:
  - `LeXtract.Error.Invalid.Config` - Invalid configuration options
  - `LeXtract.Error.Invalid.Template` - Invalid template format
  - `LeXtract.Error.External.TemplateRead` - Failed to read template file
  - `LeXtract.Error.External.Annotation` - LLM request failure

  ## Provider Configuration

  LeXtract uses ReqLLM for LLM integration. Configure providers via options:

  ```elixir
  # OpenAI
  LeXtract.extract(text,
    model: "gpt-4o-mini",
    provider: :openai,
    api_key: System.get_env("OPENAI_API_KEY")
  )

  # Gemini
  LeXtract.extract(text,
    model: "gemini-2.0-flash",
    provider: :gemini,
    api_key: System.get_env("GEMINI_API_KEY")
  )

  # Anthropic
  LeXtract.extract(text,
    model: "claude-3-5-sonnet-20241022",
    provider: :anthropic,
    api_key: System.get_env("ANTHROPIC_API_KEY")
  )
  ```
  """

  alias LeXtract.{Annotator, Document, Prompting}

  @options_schema [
    prompt: [
      type: :string,
      doc: "Extraction prompt/description"
    ],
    examples: [
      type: {:list, :any},
      doc: "List of example extractions (maps with :text and :extractions keys)"
    ],
    template_file: [
      type: :string,
      doc: "Path to template file (.json or .yaml)"
    ],
    model: [
      type: :string,
      required: true,
      doc: "LLM model identifier (e.g., 'gpt-4o-mini')"
    ],
    provider: [
      type: :atom,
      required: true,
      doc: "LLM provider (:openai, :gemini, :anthropic, etc.)"
    ],
    api_key: [
      type: :string,
      required: true,
      doc: "API key for the LLM provider"
    ],
    format: [
      type: {:in, [:json, :yaml]},
      default: :yaml,
      doc: "Output format for extractions"
    ],
    fence_output: [
      type: :boolean,
      default: false,
      doc: "Expect fenced code blocks in LLM response"
    ],
    use_structured_output: [
      type: :boolean,
      default: false,
      doc: "Use structured output mode (generate_object)"
    ],
    max_char_buffer: [
      type: :pos_integer,
      default: 1000,
      doc: "Maximum chunk size in characters"
    ],
    chunk_overlap: [
      type: :non_neg_integer,
      default: 200,
      doc: "Character overlap between chunks"
    ],
    batch_size: [
      type: :pos_integer,
      default: 5,
      doc: "Number of chunks per LLM batch"
    ],
    extraction_passes: [
      type: :pos_integer,
      default: 1,
      doc: "Number of extraction passes for multi-pass extraction"
    ],
    max_concurrency: [
      type: :pos_integer,
      default: 8,
      doc: "Maximum concurrent LLM requests"
    ],
    temperature: [
      type: :float,
      default: 0.0,
      doc: "LLM sampling temperature (0.0-1.0)"
    ],
    max_tokens: [
      type: :pos_integer,
      doc: "Maximum tokens in LLM response"
    ],
    timeout: [
      type: :pos_integer,
      default: 60_000,
      doc: "Request timeout in milliseconds"
    ],
    attribute_suffix: [
      type: :string,
      default: "_attributes",
      doc: "Suffix for attribute keys in structured output"
    ]
  ]

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

      iex> {:ok, stream} = LeXtract.extract(
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
  @spec extract(
          String.t() | [String.t()] | [Document.t()],
          keyword()
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
          String.t() | [String.t()] | [Document.t()],
          keyword()
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
  @spec extract_from_file(Path.t(), keyword()) ::
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
  @spec validate_options(keyword()) :: {:ok, keyword()} | {:error, Exception.t()}
  def validate_options(opts) do
    case NimbleOptions.validate(opts, @options_schema) do
      {:ok, validated} ->
        validate_template_options(validated)

      {:error, %NimbleOptions.ValidationError{message: message}} ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(errors: "Invalid extraction options: #{message}")}
    end
  end

  defp validate_template_options(opts) do
    has_inline = Keyword.has_key?(opts, :prompt) or Keyword.has_key?(opts, :examples)
    has_file = Keyword.has_key?(opts, :template_file)

    cond do
      has_inline and has_file ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors:
             "Cannot specify both inline template options (:prompt, :examples) and :template_file"
         )}

      not has_inline and not has_file ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors:
             "Must specify either inline template options (:prompt with optional :examples) or :template_file"
         )}

      has_inline and not Keyword.has_key?(opts, :prompt) ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors: "When using inline template, :prompt is required"
         )}

      true ->
        {:ok, opts}
    end
  end

  defp build_template(opts) do
    cond do
      Keyword.has_key?(opts, :template_file) ->
        read_template_file(opts)

      Keyword.has_key?(opts, :prompt) ->
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
      api_key: Keyword.fetch!(opts, :api_key),
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
