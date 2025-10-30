defmodule LeXtractTest do
  use ExUnit.Case, async: true
  use Mimic

  doctest LeXtract

  alias LeXtract.{Annotator, AnnotatedDocument, Document}

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(Annotator)
    :ok
  end

  describe "validate_options/1" do
    test "validates correct minimal options" do
      {:ok, validated} =
        LeXtract.validate_options(
          prompt: "Extract entities",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert Keyword.get(validated, :prompt) == "Extract entities"
      assert Keyword.get(validated, :model) == "gpt-4o-mini"
      assert Keyword.get(validated, :provider) == :openai
      assert Keyword.get(validated, :format) == :yaml
    end

    test "validates template_file option" do
      {:ok, validated} =
        LeXtract.validate_options(
          template_file: "/tmp/template.yaml",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert Keyword.get(validated, :template_file) == "/tmp/template.yaml"
    end

    test "validates all optional parameters" do
      {:ok, validated} =
        LeXtract.validate_options(
          prompt: "Extract",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key",
          temperature: 0.5,
          max_tokens: 1000,
          timeout: 30_000,
          format: :json,
          fence_output: true,
          use_structured_output: true,
          max_char_buffer: 2000,
          chunk_overlap: 100,
          batch_size: 10,
          extraction_passes: 2,
          max_concurrency: 4,
          attribute_suffix: "_attrs"
        )

      assert Keyword.get(validated, :temperature) == 0.5
      assert Keyword.get(validated, :max_tokens) == 1000
      assert Keyword.get(validated, :timeout) == 30_000
      assert Keyword.get(validated, :format) == :json
      assert Keyword.get(validated, :fence_output) == true
      assert Keyword.get(validated, :use_structured_output) == true
      assert Keyword.get(validated, :max_char_buffer) == 2000
      assert Keyword.get(validated, :chunk_overlap) == 100
      assert Keyword.get(validated, :batch_size) == 10
      assert Keyword.get(validated, :extraction_passes) == 2
      assert Keyword.get(validated, :max_concurrency) == 4
      assert Keyword.get(validated, :attribute_suffix) == "_attrs"
    end

    test "returns error for missing required model" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          provider: :openai,
          api_key: "key"
        )

      assert Exception.message(error) =~ "required"
      assert Exception.message(error) =~ "model"
    end

    test "returns error for missing required provider" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          model: "gpt-4o-mini",
          api_key: "key"
        )

      assert Exception.message(error) =~ "required"
      assert Exception.message(error) =~ "provider"
    end

    test "returns error for invalid temperature type" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key",
          temperature: "invalid"
        )

      assert Exception.message(error) =~ "temperature"
    end

    test "returns error for invalid format" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key",
          format: :xml
        )

      assert Exception.message(error) =~ "format"
    end

    test "returns error for invalid max_char_buffer" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key",
          max_char_buffer: -1
        )

      assert Exception.message(error) =~ "max_char_buffer"
    end

    test "returns error when both inline and file templates specified" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          template_file: "/tmp/template.yaml",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key"
        )

      assert Exception.message(error) =~ "Cannot specify both"
    end

    test "returns error when no template specified" do
      {:error, error} =
        LeXtract.validate_options(
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key"
        )

      assert Exception.message(error) =~ "Must specify either"
    end

    test "returns error when only examples specified without prompt" do
      {:error, error} =
        LeXtract.validate_options(
          examples: [%{text: "test", extractions: []}],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key"
        )

      assert Exception.message(error) =~ "prompt is required"
    end
  end

  describe "extract/2 with inline template" do
    test "returns stream for single text input" do
      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, stream} =
        LeXtract.extract(
          "Test text",
          prompt: "Extract entities",
          examples: [],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert is_struct(stream, Stream)
      results = Enum.to_list(stream)
      assert length(results) == 1
    end

    test "returns stream for multiple text inputs" do
      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, stream} =
        LeXtract.extract(
          ["Text 1", "Text 2", "Text 3"],
          prompt: "Extract entities",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      results = Enum.to_list(stream)
      assert length(results) == 3
    end

    test "returns stream for Document structs" do
      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      doc1 = Document.create("Doc 1")
      doc2 = Document.create("Doc 2")

      {:ok, stream} =
        LeXtract.extract(
          [doc1, doc2],
          prompt: "Extract entities",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      results = Enum.to_list(stream)
      assert length(results) == 2
    end

    test "handles examples with different formats" do
      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, _stream} =
        LeXtract.extract(
          "Test",
          prompt: "Extract",
          examples: [
            %{text: "Example 1", extractions: []},
            %{"text" => "Example 2", "extractions" => []}
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )
    end
  end

  describe "extract/2 with template file" do
    test "reads YAML template file" do
      template_path = "/tmp/test_template_#{:rand.uniform(10000)}.yaml"

      template_content = """
      description: Extract entities
      examples:
        - text: "Sample"
          extractions: []
      """

      File.write!(template_path, template_content)

      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, stream} =
        LeXtract.extract(
          "Test text",
          template_file: template_path,
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert is_struct(stream, Stream)
      File.rm(template_path)
    end

    test "reads JSON template file" do
      template_path = "/tmp/test_template_#{:rand.uniform(10000)}.json"

      template_content = """
      {
        "description": "Extract entities",
        "examples": []
      }
      """

      File.write!(template_path, template_content)

      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, stream} =
        LeXtract.extract(
          "Test text",
          template_file: template_path,
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert is_struct(stream, Stream)
      File.rm(template_path)
    end

    test "handles template file read error" do
      {:error, error} =
        LeXtract.extract(
          "Test text",
          template_file: "/nonexistent/template.yaml",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert %LeXtract.Error.External.TemplateRead{} = error
    end
  end

  describe "extract!/2" do
    test "returns stream on success" do
      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      stream =
        LeXtract.extract!(
          "Test text",
          prompt: "Extract entities",
          examples: [],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert is_struct(stream, Stream)
    end

    test "raises on validation error" do
      assert_raise LeXtract.Error.Invalid.Config, fn ->
        LeXtract.extract!(
          "Test text",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key"
        )
      end
    end

    test "raises on template read error" do
      assert_raise LeXtract.Error.External.TemplateRead, fn ->
        LeXtract.extract!(
          "Test text",
          template_file: "/nonexistent/template.yaml",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )
      end
    end
  end

  describe "extract_from_file/2" do
    test "reads file and extracts" do
      file_path = "/tmp/test_doc_#{:rand.uniform(10000)}.txt"
      content = "Test document content"
      File.write!(file_path, content)

      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, stream} =
        LeXtract.extract_from_file(
          file_path,
          prompt: "Extract entities",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      results = Enum.to_list(stream)
      assert length(results) == 1
      [doc] = results
      assert doc.text == content

      File.rm(file_path)
    end

    test "returns error for nonexistent file" do
      {:error, error} =
        LeXtract.extract_from_file(
          "/nonexistent/file.txt",
          prompt: "Extract entities",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert %LeXtract.Error.External.TemplateRead{} = error
    end
  end

  describe "private function coverage" do
    test "handles mixed Document and string inputs" do
      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      doc1 = Document.create("Doc 1")

      {:ok, stream} =
        LeXtract.extract(
          [doc1, "String text"],
          prompt: "Extract entities",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      results = Enum.to_list(stream)
      assert length(results) == 2
    end

    test "builds req_llm_config with all optional parameters" do
      Annotator
      |> stub(:new, fn _template, config, _opts ->
        assert Keyword.get(config, :temperature) == 0.7
        assert Keyword.get(config, :max_tokens) == 2000
        assert Keyword.get(config, :receive_timeout) == 90_000

        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: config,
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, _stream} =
        LeXtract.extract(
          "Test",
          prompt: "Extract",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key",
          temperature: 0.7,
          max_tokens: 2000,
          timeout: 90_000
        )
    end

    test "determines template format for .yml extension" do
      template_path = "/tmp/test_template_#{:rand.uniform(10000)}.yml"

      template_content = """
      description: Extract entities
      examples: []
      """

      File.write!(template_path, template_content)

      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, _stream} =
        LeXtract.extract(
          "Test",
          template_file: template_path,
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      File.rm(template_path)
    end

    test "determines template format for unknown extension defaults to yaml" do
      template_path = "/tmp/test_template_#{:rand.uniform(10000)}.txt"

      template_content = """
      description: Extract entities
      examples: []
      """

      File.write!(template_path, template_content)

      Annotator
      |> stub(:new, fn _template, _config, _opts ->
        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, _stream} =
        LeXtract.extract(
          "Test",
          template_file: template_path,
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      File.rm(template_path)
    end

    test "normalizes examples with string keys" do
      Annotator
      |> stub(:new, fn template, _config, _opts ->
        examples = Map.get(template, :examples, [])
        assert length(examples) == 2
        [ex1, ex2] = examples
        assert ex1.text == "Example 1"
        assert ex2.text == "Example 2"

        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: template,
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, _stream} =
        LeXtract.extract(
          "Test",
          prompt: "Extract",
          examples: [
            %{"text" => "Example 1", "extractions" => []},
            %{text: "Example 2", extractions: []}
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )
    end

    test "handles empty examples list" do
      Annotator
      |> stub(:new, fn template, _config, _opts ->
        examples = Map.get(template, :examples, [])
        assert examples == []

        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: template,
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          req_llm_config: [],
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(
            text: doc.text,
            document_id: doc.document_id,
            extractions: []
          )
        end)
      end)

      {:ok, _stream} =
        LeXtract.extract(
          "Test",
          prompt: "Extract",
          examples: [],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )
    end
  end
end
