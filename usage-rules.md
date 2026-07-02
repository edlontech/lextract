# LeXtract usage rules

LeXtract is an LLM-powered structured text extraction library for Elixir (a port of
Google's LangExtract). It extracts typed entities from unstructured text and aligns
them back to their exact character positions in the source.

## Core API

`LeXtract.extract/2` is the single entry point. It returns a **lazy `Stream`**, not a
list — nothing runs until you enumerate it (`Enum.to_list/1`, `Stream.each/2`, etc.).

```elixir
{:ok, stream} =
  LeXtract.extract(
    "Dr. Smith prescribed aspirin 100mg to the patient.",
    prompt: "Extract medical entities",
    examples: [
      %{
        text: "Patient takes ibuprofen 200mg",
        extractions: [%{extraction_class: "Medication", name: "ibuprofen", dosage: "200mg"}]
      }
    ],
    provider: :openai,
    model: "gpt-4o-mini"
  )

docs = Enum.to_list(stream) # [%LeXtract.AnnotatedDocument{}, ...]
```

Related functions:

- `LeXtract.extract!/2` — same as `extract/2` but returns the stream directly or raises.
- `LeXtract.extract_from_file/2` — reads a file, then delegates to `extract/2`.
- `LeXtract.validate_options/1` — validates core options only (not LLM adapter opts).

## Input

`input` (first arg) may be a `String.t()`, a `[String.t()]`, or a `[LeXtract.Document.t()]`.
A single string is wrapped into one document automatically.

## Template: inline OR file (never both)

Extraction is driven by a template. Provide **exactly one** of:

- Inline: `prompt:` (required) plus optional `examples:`.
- File: `template_file:` pointing at a `.json`/`.yaml`/`.yml` file.

Supplying both, or neither, returns `{:error, %LeXtract.Error.Invalid.Config{}}`.

`examples` is a list of maps with `:text` and `:extractions` keys (string keys also
accepted). Good examples strongly improve extraction quality — provide them.

Template file (YAML):

```yaml
description: Extract medication entities with dosage and frequency
examples:
  - text: "Patient takes aspirin 100mg twice daily"
    extractions:
      - extraction_class: Medication
        name: aspirin
        dosage: 100mg
        frequency: twice daily
```

## Options (core)

All optional except the template requirement above. Defaults shown.

| Option | Default | Meaning |
| --- | --- | --- |
| `prompt` | — | Extraction instruction (required for inline template) |
| `examples` | `[]` | Few-shot examples (`%{text:, extractions:}`) |
| `template_file` | — | Path to `.json`/`.yaml` template |
| `format` | `:yaml` | LLM output format: `:json` or `:yaml` |
| `fence_output` | `false` | Expect fenced code blocks in the LLM response |
| `use_structured_output` | `false` | Use `generate_object` + schema validation (more reliable) |
| `max_char_buffer` | `1000` | Max chunk size in characters |
| `chunk_overlap` | `200` | Character overlap between chunks |
| `batch_size` | `5` | Chunks per LLM batch |
| `extraction_passes` | `1` | Multi-pass extraction for higher recall |
| `max_concurrency` | `8` | Max concurrent LLM requests |
| `attribute_suffix` | `"_attributes"` | Suffix for attribute keys in structured output |

Prefer `use_structured_output: true` when the provider supports it — it validates
against a schema inferred from your examples and is more reliable than parsing free text.

## LLM adapter selection

LeXtract talks to LLMs through the `LeXtract.LLM` behaviour. The adapter is resolved
in this order:

1. Per-call `:llm` option — `Module` or `{Module, adapter_opts}`.
2. `config :lextract, :llm, {Module, opts}`.
3. Default `{LeXtract.LLM.ReqLLM, []}`.

The default adapter is backed by [`req_llm`](https://hex.pm/packages/req_llm), which is
an **optional** dependency — add `{:req_llm, "~> 1.0"}` to your deps to use it. If you
ship your own adapter, `req_llm` is not required.

```elixir
# App config
config :lextract, :llm,
  {LeXtract.LLM.ReqLLM, provider: :openai, model: "gpt-4o-mini", api_key: System.get_env("OPENAI_API_KEY")}

# Per-call override
LeXtract.extract(text, prompt: "...", llm: {LeXtract.LLM.ReqLLM, provider: :openai, model: "gpt-4o-mini"})
```

Legacy top-level `provider:`, `model:`, `api_key:`, `temperature:`, `max_tokens:`,
`timeout:` are still accepted and folded into the resolved adapter's opts when no
explicit `:llm` is given. When `api_key` is omitted, `req_llm` falls back to its own
key resolution (`config :req_llm, ...` or the provider's standard env var like
`OPENAI_API_KEY`).

## Writing a custom adapter

Implement the `LeXtract.LLM` behaviour. `generate_text/2` and `generate_object/3` are
required; `validate_opts/1` is optional (validate credentials / normalize opts ahead of
extraction). Adapters are single-shot per prompt — the core owns concurrency,
batching, and streaming, so do **not** add your own.

```elixir
defmodule MyApp.LLM.Custom do
  @behaviour LeXtract.LLM

  @impl true
  def generate_text(prompt, opts), do: {:ok, "..."}

  @impl true
  def generate_object(prompt, schema, opts), do: {:ok, %{}}

  @impl true
  def validate_opts(opts), do: {:ok, opts}
end
```

`schema` passed to `generate_object/3` is LeXtract's internal keyword representation —
each adapter translates it into its own provider format.

## Result shape

`extract/2` streams `%LeXtract.AnnotatedDocument{}`:

- `:document_id` — UUIDv7 (auto-generated if not supplied).
- `:text` — original document text.
- `:extractions` — list of `%LeXtract.Extraction{}`.
- `:metadata` — optional map.

Each `%LeXtract.Extraction{}`:

- `:extraction_class` — entity type (e.g. `"person"`, `"medication"`).
- `:extraction_text` — the extracted span.
- `:char_interval` — `%LeXtract.CharInterval{start_pos:, end_pos:}` (source position).
- `:alignment_status` — alignment quality (`LeXtract.AlignmentStatus`).
- `:attributes` — extra structured fields (dosage, frequency, ...).
- `:extraction_index`, `:group_index`, `:token_interval`, `:description`.

Helpers: `AnnotatedDocument.by_class/2`, `.extraction_classes/1`, `.count/1`,
`.has_extractions?/1`; `Extraction.aligned?/1`, `.has_attributes?/1`.

## Error handling

`extract/2` returns `{:ok, stream} | {:error, exception}`. Errors are `Splode`-based
structs under `LeXtract.Error.*` (e.g. `LeXtract.Error.Invalid.Config`,
`LeXtract.Error.Invalid.Format`, `LeXtract.Error.External.*`,
`LeXtract.Error.Processing.*`). Match on `{:error, exception}` and use
`Exception.message/1`; use `extract!/2` when you prefer raising.

Note: option validation errors surface at `extract/2`, but LLM/network errors can
surface later while **enumerating** the stream, since the stream is lazy.

## Gotchas

- The stream is lazy — enumerate it or nothing happens.
- Inline template and `template_file` are mutually exclusive.
- `format` accepts only `:json` or `:yaml`.
- The default adapter needs `req_llm` in your deps; without it, configure a custom adapter.
