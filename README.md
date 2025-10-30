# LeXtract

LLM-powered text extraction library for Elixir. Based on Google's [LangExtract](https://github.com/google/langextract)

LeXtract enables you to extract structured information from unstructured text using Large Language Models (LLMs). It provides a simple, streaming API with support for multiple LLM providers.

## Features

- **Multi-Provider LLM Support** - Works with OpenAI, Gemini, Anthropic, and other providers through ReqLLM
- **Streaming API** - Memory-efficient batch processing with lazy streams
- **Automatic Text Chunking** - Handles long documents with configurable chunk sizes and overlap
- **Character-Level Alignment** - Precise alignment of extractions to source text positions
- **Schema Generation** - Automatic schema inference from examples
- **Template-Based Configuration** - Reusable extraction templates in JSON or YAML
- **Structured Output Mode** - Enhanced reliability with schema validation
- **Multi-Pass Extraction** - Improved recall through multiple extraction passes
- **Flexible Output Formats** - Support for JSON and YAML output formats

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
  provider: :openai
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
  provider: :openai
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
  batch_size: 5
)

stream
|> Stream.each(fn annotated_doc ->
  IO.puts("Document: #{annotated_doc.document_id}")
  IO.puts("Extractions: #{length(annotated_doc.extractions)}")
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
  use_structured_output: true
)
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
