# LeXtract

[![Hex](https://img.shields.io/hexpm/v/lextract?style=flat-square)](https://hex.pm/packages/lextract) [![Coverage Status](https://coveralls.io/repos/github/YgorCastor/lextract/badge.svg?branch=master)](https://coveralls.io/github/YgorCastor/lextract?branch=master)

LLM-powered text extraction library for Elixir. Based on Google's [LangExtract](https://github.com/google/langextract)

LeXtract enables you to extract structured information from unstructured text using Large Language Models (LLMs). It provides a simple, streaming API with support for multiple LLM providers.

## Features

- **Multi-Provider LLM Support** - Works with OpenAI, Gemini, Anthropic, and other providers through ReqLLM
- **Pluggable LLM Adapter** - Swap the LLM backend by implementing the `LeXtract.LLM` behaviour
- **Streaming API** - Memory-efficient batch processing with lazy streams
- **Automatic Text Chunking** - Handles long documents with configurable chunk sizes and overlap
- **Character-Level Alignment** - Precise alignment of extractions to source text positions
- **Schema Generation** - Automatic schema inference from examples
- **Template-Based Configuration** - Reusable extraction templates in JSON or YAML
- **Structured Output Mode** - Enhanced reliability with schema validation
- **Multi-Pass Extraction** - Improved recall through multiple extraction passes
- **Flexible Output Formats** - Support for JSON and YAML output formats

## Installation

Add `lextract` to your list of dependencies in `mix.exs`. The default LLM adapter is
backed by [`req_llm`](https://hex.pm/packages/req_llm), which is an **optional**
dependency of `lextract` — add it explicitly to use the default adapter:

```elixir
def deps do
  [
    {:lextract, "~> 0.1.0"},
    {:req_llm, "~> 1.0"}
  ]
end
```

If you provide your own `LeXtract.LLM` adapter (see [LLM Adapter Configuration](#llm-adapter-configuration)),
`req_llm` is not required.

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

## LLM Adapter Configuration

LeXtract talks to LLMs through the `LeXtract.LLM` behaviour. The default
`LeXtract.LLM.ReqLLM` adapter (backed by `req_llm`, see [Installation](#installation))
is used unless you configure a different one.

### App config

Set a default adapter and its options at the application level:

```elixir
config :lextract, :llm,
  {LeXtract.LLM.ReqLLM, provider: :openai, model: "gpt-4o-mini", api_key: System.get_env("OPENAI_API_KEY")}
```

If you omit `api_key`, `req_llm` falls back to its own key resolution
(`config :req_llm, openai_api_key: ...` or the provider's standard environment
variable, e.g. `OPENAI_API_KEY`).

### Per-call override

Override the adapter for a single call with the `:llm` option:

```elixir
{:ok, stream} = LeXtract.extract(
  "Dr. Smith prescribed aspirin 100mg to the patient.",
  prompt: "Extract medical entities from the text",
  llm: {LeXtract.LLM.ReqLLM, provider: :openai, model: "gpt-4o-mini"}
)
```

### Legacy shorthand

Top-level `provider:`/`model:` options (as used in the Quick Start examples above) are
still supported and are routed to the default `LeXtract.LLM.ReqLLM` adapter:

```elixir
{:ok, stream} = LeXtract.extract(
  "Dr. Smith prescribed aspirin 100mg to the patient.",
  prompt: "Extract medical entities from the text",
  provider: :openai,
  model: "gpt-4o-mini"
)
```

### Writing your own adapter

Implement the `LeXtract.LLM` behaviour to plug in a different backend:

```elixir
defmodule MyApp.LLM.CustomAdapter do
  @behaviour LeXtract.LLM

  @impl LeXtract.LLM
  def generate_text(prompt, opts), do: # ...

  @impl LeXtract.LLM
  def generate_object(prompt, schema, opts), do: # ...

  @impl LeXtract.LLM
  def validate_opts(opts), do: {:ok, opts}
end
```

`generate_text/2` and `generate_object/3` are required; `validate_opts/1` is optional
and, when present, is used to validate/normalize adapter options before extraction
starts.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
