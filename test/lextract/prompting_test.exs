defmodule LeXtract.PromptingTest do
  use ExUnit.Case, async: true

  alias LeXtract.{FormatHandler, Prompting}

  doctest LeXtract.Prompting

  describe "new/3" do
    test "creates prompt generator with defaults" do
      template = %{
        description: "Extract entities",
        examples: []
      }

      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      assert generator.template == template
      assert generator.format_handler == handler
      assert generator.examples_heading == "Examples"
      assert generator.question_prefix == "Q: "
      assert generator.answer_prefix == "A: "
    end

    test "accepts custom prefixes and headings" do
      template = %{description: "Test", examples: []}
      handler = FormatHandler.new(:yaml)

      generator =
        Prompting.new(template, handler,
          examples_heading: "Few-shot Examples",
          question_prefix: "Question: ",
          answer_prefix: "Answer: "
        )

      assert generator.examples_heading == "Few-shot Examples"
      assert generator.question_prefix == "Question: "
      assert generator.answer_prefix == "Answer: "
    end

    test "validates template has description" do
      handler = FormatHandler.new(:json)

      assert_raise ArgumentError, ~r/non-empty description/, fn ->
        Prompting.new(%{examples: []}, handler)
      end

      assert_raise ArgumentError, ~r/non-empty description/, fn ->
        Prompting.new(%{description: "", examples: []}, handler)
      end

      assert_raise ArgumentError, ~r/non-empty description/, fn ->
        Prompting.new(%{description: "   ", examples: []}, handler)
      end
    end

    test "validates examples is a list" do
      handler = FormatHandler.new(:json)

      assert_raise ArgumentError, ~r/examples must be a list/, fn ->
        Prompting.new(%{description: "Test", examples: "not a list"}, handler)
      end
    end
  end

  describe "render/3" do
    test "renders simple prompt without examples" do
      template = %{
        description: "Extract people from text",
        examples: []
      }

      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      prompt = Prompting.render(generator, "John Doe works here")

      assert String.contains?(prompt, "Extract people from text")
      assert String.contains?(prompt, "Q: John Doe works here")
      assert String.contains?(prompt, "A: ")
      refute String.contains?(prompt, "Examples")
    end

    test "renders prompt with few-shot examples in JSON" do
      template = %{
        description: "Extract medications",
        examples: [
          %{
            text: "Patient takes aspirin",
            extractions: [%{medication: "aspirin"}]
          }
        ]
      }

      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      prompt = Prompting.render(generator, "Patient prescribed metformin")

      assert String.contains?(prompt, "Extract medications")
      assert String.contains?(prompt, "Examples")
      assert String.contains?(prompt, "Q: Patient takes aspirin")
      assert String.contains?(prompt, "aspirin")
      assert String.contains?(prompt, "Q: Patient prescribed metformin")
    end

    test "renders prompt with few-shot examples in YAML" do
      template = %{
        description: "Extract entities",
        examples: [
          %{
            text: "Test text",
            extractions: [%{entity: "test"}]
          }
        ]
      }

      handler = FormatHandler.new(:yaml)
      generator = Prompting.new(template, handler)

      prompt = Prompting.render(generator, "Sample question")

      assert String.contains?(prompt, "Extract entities")
      assert String.contains?(prompt, "Examples")
      assert String.contains?(prompt, "Q: Test text")
      assert String.contains?(prompt, "entity:")
    end

    test "includes additional context when provided" do
      template = %{description: "Extract", examples: []}
      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      prompt =
        Prompting.render(generator, "Question text", additional_context: "Focus on medications")

      assert String.contains?(prompt, "Extract")
      assert String.contains?(prompt, "Focus on medications")
      assert String.contains?(prompt, "Question text")
    end

    test "handles unicode in examples" do
      template = %{
        description: "Extract",
        examples: [
          %{
            text: "Patient 👨 takes 💊",
            extractions: [%{emoji: "💊"}]
          }
        ]
      }

      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      prompt = Prompting.render(generator, "Test")

      assert String.contains?(prompt, "👨")
      assert String.contains?(prompt, "💊")
    end

    test "handles multiple examples" do
      template = %{
        description: "Extract",
        examples: [
          %{text: "Example 1", extractions: [%{entity: "one"}]},
          %{text: "Example 2", extractions: [%{entity: "two"}]}
        ]
      }

      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      prompt = Prompting.render(generator, "Test")

      assert String.contains?(prompt, "Example 1")
      assert String.contains?(prompt, "Example 2")
    end
  end

  describe "format_example/2" do
    test "formats example as Q&A pair in JSON" do
      template = %{description: "Test", examples: []}
      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      example = %{
        text: "John Doe works here",
        extractions: [%{person: "John Doe"}]
      }

      formatted = Prompting.format_example(generator, example)

      assert String.contains?(formatted, "Q: John Doe works here")
      assert String.contains?(formatted, "A: ")
      assert String.contains?(formatted, "person")
    end

    test "formats example with custom prefixes" do
      template = %{description: "Test", examples: []}
      handler = FormatHandler.new(:json)

      generator =
        Prompting.new(template, handler,
          question_prefix: "INPUT: ",
          answer_prefix: "OUTPUT: "
        )

      example = %{
        text: "Test",
        extractions: [%{entity: "test"}]
      }

      formatted = Prompting.format_example(generator, example)

      assert String.contains?(formatted, "INPUT: Test")
      assert String.contains?(formatted, "OUTPUT: ")
    end

    test "handles example with string keys" do
      template = %{description: "Test", examples: []}
      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      example = %{
        "text" => "Sample",
        "extractions" => [%{"entity" => "sample"}]
      }

      formatted = Prompting.format_example(generator, example)

      assert String.contains?(formatted, "Q: Sample")
    end

    test "handles empty extractions" do
      template = %{description: "Test", examples: []}
      handler = FormatHandler.new(:json)
      generator = Prompting.new(template, handler)

      example = %{text: "No entities", extractions: []}

      formatted = Prompting.format_example(generator, example)

      assert String.contains?(formatted, "Q: No entities")
      assert String.contains?(formatted, "A: ")
    end
  end

  describe "read_template/2" do
    setup do
      tmp_dir = System.tmp_dir!()
      json_path = Path.join(tmp_dir, "test_template_#{:rand.uniform(100_000)}.json")
      yaml_path = Path.join(tmp_dir, "test_template_#{:rand.uniform(100_000)}.yaml")

      on_exit(fn ->
        File.rm(json_path)
        File.rm(yaml_path)
      end)

      {:ok, json_path: json_path, yaml_path: yaml_path}
    end

    test "reads template from JSON file", %{json_path: path} do
      template_json = """
      {
        "description": "Extract medications",
        "examples": [
          {
            "text": "Patient takes aspirin",
            "extractions": [{"medication": "aspirin"}]
          }
        ]
      }
      """

      File.write!(path, template_json)

      assert {:ok, template} = Prompting.read_template(path, :json)
      assert template.description == "Extract medications"
      assert length(template.examples) == 1
      assert hd(template.examples).text == "Patient takes aspirin"
    end

    test "reads template from YAML file", %{yaml_path: path} do
      template_yaml = """
      description: Extract people
      examples:
        - text: John Doe
          extractions:
            - person: John Doe
      """

      File.write!(path, template_yaml)

      assert {:ok, template} = Prompting.read_template(path, :yaml)
      assert template.description == "Extract people"
      assert length(template.examples) == 1
    end

    test "returns error for non-existent file" do
      assert {:error, reason} = Prompting.read_template("/nonexistent/file.json", :json)
      assert String.contains?(reason, "Failed to read")
    end

    test "returns error for malformed JSON", %{json_path: path} do
      File.write!(path, "{invalid json")

      assert {:error, reason} = Prompting.read_template(path, :json)
      assert String.contains?(reason, "Failed to parse")
    end

    test "returns error for template without description", %{json_path: path} do
      File.write!(path, ~s({"examples": []}))

      assert {:error, reason} = Prompting.read_template(path, :json)
      assert String.contains?(reason, "description")
    end
  end
end
