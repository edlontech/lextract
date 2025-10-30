defmodule LeXtract.Prompting do
  @moduledoc """
  Prompt generation for LLM extraction.

  Creates structured prompts with few-shot examples to guide the LLM
  in extracting entities from text in the desired format.

  ## Examples

      iex> template = %{
      ...>   description: "Extract medications from clinical text",
      ...>   examples: [
      ...>     %{
      ...>       text: "Patient takes aspirin",
      ...>       extractions: [
      ...>         %{extraction_class: "medication", extraction_text: "aspirin"}
      ...>       ]
      ...>     }
      ...>   ]
      ...> }
      iex> handler = LeXtract.FormatHandler.new(:json)
      iex> generator = LeXtract.Prompting.new(template, handler)
      iex> is_struct(generator, LeXtract.Prompting)
      true

  """

  alias LeXtract.{Document, FormatHandler}

  @type template :: %{
          description: String.t(),
          examples: [Document.example()]
        }

  @type t :: %__MODULE__{
          template: template(),
          format_handler: FormatHandler.t(),
          examples_heading: String.t(),
          question_prefix: String.t(),
          answer_prefix: String.t()
        }

  @enforce_keys [:template, :format_handler]
  defstruct [
    :template,
    :format_handler,
    examples_heading: "Examples",
    question_prefix: "Q: ",
    answer_prefix: "A: "
  ]

  @doc """
  Creates a new prompt generator.

  ## Parameters

    * `template` - Prompt template with description and examples
    * `format_handler` - Format handler for JSON/YAML output
    * `opts` - Options (see below)

  ## Options

    * `:examples_heading` - Heading text for examples section (default: "Examples")
    * `:question_prefix` - Prefix for question lines (default: "Q: ")
    * `:answer_prefix` - Prefix for answer lines (default: "A: ")

  ## Examples

      iex> template = %{description: "Extract entities", examples: []}
      iex> handler = LeXtract.FormatHandler.new(:json)
      iex> generator = LeXtract.Prompting.new(template, handler)
      iex> generator.examples_heading
      "Examples"

      iex> template = %{description: "Extract entities", examples: []}
      iex> handler = LeXtract.FormatHandler.new(:yaml)
      iex> generator = LeXtract.Prompting.new(template, handler, examples_heading: "Few-shot Examples")
      iex> generator.examples_heading
      "Few-shot Examples"

  """
  @spec new(template(), FormatHandler.t(), keyword()) :: t()
  def new(template, format_handler, opts \\ []) do
    validate_template!(template)

    %__MODULE__{
      template: template,
      format_handler: format_handler,
      examples_heading: Keyword.get(opts, :examples_heading, "Examples"),
      question_prefix: Keyword.get(opts, :question_prefix, "Q: "),
      answer_prefix: Keyword.get(opts, :answer_prefix, "A: ")
    }
  end

  @doc """
  Renders a complete prompt for the LLM.

  Combines:
  - Template description
  - Optional additional context
  - Few-shot examples (formatted)
  - The question text
  - Answer prefix to guide LLM response

  ## Parameters

    * `generator` - The prompt generator
    * `question` - Text to extract from
    * `opts` - Options (see below)

  ## Options

    * `:additional_context` - Extra context to include before examples

  ## Returns

  String prompt ready to send to LLM.

  ## Examples

      iex> template = %{description: "Extract people", examples: []}
      iex> handler = LeXtract.FormatHandler.new(:json)
      iex> generator = LeXtract.Prompting.new(template, handler)
      iex> prompt = LeXtract.Prompting.render(generator, "John Doe works here")
      iex> String.contains?(prompt, "Extract people")
      true
      iex> String.contains?(prompt, "Q: John Doe works here")
      true

  """
  @spec render(t(), String.t(), keyword()) :: String.t()
  def render(%__MODULE__{} = generator, question, opts \\ []) when is_binary(question) do
    additional_context = Keyword.get(opts, :additional_context)

    prompt_lines = [
      "#{generator.template.description}\n"
    ]

    prompt_lines =
      if additional_context do
        prompt_lines ++ ["#{additional_context}\n"]
      else
        prompt_lines
      end

    prompt_lines =
      if has_examples?(generator) do
        example_lines =
          generator.template.examples
          |> Enum.map(&format_example(generator, &1))

        prompt_lines ++ [generator.examples_heading] ++ example_lines
      else
        prompt_lines
      end

    prompt_lines =
      prompt_lines ++ ["#{generator.question_prefix}#{question}", generator.answer_prefix]

    Enum.join(prompt_lines, "\n")
  end

  @doc """
  Formats a single example as text (Q&A format).

  Converts an example into:
  Q: <example text>
  A: <formatted extractions in JSON/YAML>

  ## Examples

      iex> template = %{description: "Extract", examples: []}
      iex> handler = LeXtract.FormatHandler.new(:json)
      iex> generator = LeXtract.Prompting.new(template, handler)
      iex> example = %{text: "John Doe", extractions: [%{entity: "John Doe"}]}
      iex> formatted = LeXtract.Prompting.format_example(generator, example)
      iex> String.contains?(formatted, "Q: John Doe")
      true

  """
  @spec format_example(t(), Document.example()) :: String.t()
  def format_example(%__MODULE__{} = generator, example) when is_map(example) do
    question_text = Map.get(example, :text) || Map.get(example, "text")
    extractions = Map.get(example, :extractions) || Map.get(example, "extractions") || []

    answer_text = format_extractions(generator, extractions)

    "#{generator.question_prefix}#{question_text}\n#{generator.answer_prefix}#{answer_text}"
  end

  @doc """
  Reads a prompt template from a JSON or YAML file.

  ## Parameters

    * `path` - File path to template
    * `format` - :json or :yaml

  ## Returns

  `{:ok, template}` or `{:error, reason}`

  ## Examples

      iex> File.write!("/tmp/test_template.json", ~s({"description": "Test", "examples": []}))
      iex> {:ok, template} = LeXtract.Prompting.read_template("/tmp/test_template.json", :json)
      iex> template.description
      "Test"
      iex> File.rm("/tmp/test_template.json")
      :ok

  """
  @spec read_template(Path.t(), :json | :yaml) ::
          {:ok, template()} | {:error, String.t()}
  def read_template(path, format) when format in [:json, :yaml] do
    case File.read(path) do
      {:ok, content} ->
        case FormatHandler.parse(content, format) do
          {:ok, data} ->
            parse_template_data(data)

          {:error, reason} ->
            {:error, "Failed to parse template file: #{reason}"}
        end

      {:error, reason} ->
        {:error, "Failed to read template file: #{:file.format_error(reason)}"}
    end
  end

  defp validate_template!(template) when is_map(template) do
    description = Map.get(template, :description) || Map.get(template, "description")

    unless is_binary(description) and String.trim(description) != "" do
      raise ArgumentError, "Template must have a non-empty description"
    end

    examples = Map.get(template, :examples) || Map.get(template, "examples") || []

    unless is_list(examples) do
      raise ArgumentError, "Template examples must be a list"
    end

    :ok
  end

  defp has_examples?(%__MODULE__{template: template}) do
    examples = Map.get(template, :examples) || Map.get(template, "examples") || []
    length(examples) > 0
  end

  defp format_extractions(%__MODULE__{format_handler: handler}, extractions) do
    case handler.format do
      :json ->
        case Jason.encode(extractions, pretty: true) do
          {:ok, json} -> json
          _ -> "[]"
        end

      :yaml ->
        format_as_yaml(extractions)
    end
  end

  defp format_as_yaml(extractions) when is_list(extractions) do
    Enum.map_join(extractions, "\n", &format_yaml_item/1)
  end

  defp format_yaml_item(item) when is_map(item) do
    lines =
      Enum.map_join(item, "\n", fn {key, value} ->
        format_yaml_field(key, value, "  ")
      end)

    "- " <> String.replace_prefix(lines, "  ", "")
  end

  defp format_yaml_field(key, value, indent) when is_map(value) do
    nested =
      Enum.map_join(value, "\n", fn {k, v} ->
        "#{indent}  #{k}: #{format_yaml_value(v)}"
      end)

    "#{indent}#{key}:\n#{nested}"
  end

  defp format_yaml_field(key, value, indent) do
    "#{indent}#{key}: #{format_yaml_value(value)}"
  end

  defp format_yaml_value(value) when is_binary(value), do: value
  defp format_yaml_value(value) when is_number(value), do: to_string(value)
  defp format_yaml_value(true), do: "true"
  defp format_yaml_value(false), do: "false"
  defp format_yaml_value(nil), do: "null"
  defp format_yaml_value(value), do: inspect(value)

  defp parse_template_data(data) when is_map(data) do
    description = Map.get(data, "description") || Map.get(data, :description)
    examples_raw = Map.get(data, "examples") || Map.get(data, :examples) || []

    if description do
      examples = normalize_examples(examples_raw)

      {:ok,
       %{
         description: description,
         examples: examples
       }}
    else
      {:error, "Template must have a description field"}
    end
  end

  defp parse_template_data(_) do
    {:error, "Template data must be a map"}
  end

  defp normalize_examples(examples) when is_list(examples) do
    Enum.map(examples, &normalize_example/1)
  end

  defp normalize_example(example) when is_map(example) do
    %{
      text: Map.get(example, "text") || Map.get(example, :text) || "",
      extractions: Map.get(example, "extractions") || Map.get(example, :extractions) || []
    }
  end
end
