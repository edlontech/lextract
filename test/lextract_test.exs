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
      {:ok, validated} = LeXtract.validate_options(prompt: "Extract entities")

      assert Keyword.get(validated, :prompt) == "Extract entities"
      assert Keyword.get(validated, :format) == :yaml
    end

    test "validates template_file option" do
      {:ok, validated} = LeXtract.validate_options(template_file: "/tmp/template.yaml")

      assert Keyword.get(validated, :template_file) == "/tmp/template.yaml"
    end

    test "validates all optional parameters" do
      {:ok, validated} =
        LeXtract.validate_options(
          prompt: "Extract",
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

    test "returns error for model and provider since they are adapter opts, not core opts" do
      {:error, error} =
        LeXtract.validate_options(prompt: "Extract", model: "gpt-4o-mini", provider: :openai)

      assert Exception.message(error) =~ "unknown options"
    end

    test "returns error for invalid format" do
      {:error, error} = LeXtract.validate_options(prompt: "Extract", format: :xml)

      assert Exception.message(error) =~ "format"
    end

    test "returns error for invalid max_char_buffer" do
      {:error, error} = LeXtract.validate_options(prompt: "Extract", max_char_buffer: -1)

      assert Exception.message(error) =~ "max_char_buffer"
    end

    test "returns error when both inline and file templates specified" do
      {:error, error} =
        LeXtract.validate_options(prompt: "Extract", template_file: "/tmp/template.yaml")

      assert Exception.message(error) =~ "Cannot specify both"
    end

    test "returns error when no template specified" do
      {:error, error} = LeXtract.validate_options([])

      assert Exception.message(error) =~ "Must specify either"
    end

    test "returns error when only examples specified without prompt" do
      {:error, error} =
        LeXtract.validate_options(examples: [%{text: "test", extractions: []}])

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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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

    test "builds llm_opts with all optional parameters" do
      Annotator
      |> stub(:new, fn _template, {adapter, llm_opts}, _opts ->
        assert adapter == LeXtract.LLM.ReqLLM
        assert Keyword.get(llm_opts, :provider) == :openai
        assert Keyword.get(llm_opts, :model) == "gpt-4o-mini"
        assert Keyword.get(llm_opts, :temperature) == 0.7
        assert Keyword.get(llm_opts, :max_tokens) == 2000
        assert Keyword.get(llm_opts, :timeout) == 90_000

        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          llm_adapter: adapter,
          llm_opts: llm_opts,
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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
          llm_adapter: LeXtract.LLM.ReqLLM,
          llm_opts: [],
          max_concurrency: 8,
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

  describe "llm adapter resolution" do
    test "legacy provider/model shim resolves to LeXtract.LLM.ReqLLM" do
      Annotator
      |> stub(:new, fn _template, {adapter, adapter_opts}, _opts ->
        assert adapter == LeXtract.LLM.ReqLLM
        assert Keyword.get(adapter_opts, :provider) == :openai
        assert Keyword.get(adapter_opts, :model) == "gpt-4o-mini"

        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          llm_adapter: adapter,
          llm_opts: adapter_opts,
          max_concurrency: 8,
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(text: doc.text, document_id: doc.document_id, extractions: [])
        end)
      end)

      assert {:ok, stream} =
               LeXtract.extract(
                 "Test",
                 prompt: "Extract",
                 provider: :openai,
                 model: "gpt-4o-mini",
                 api_key: "test-key"
               )

      assert length(Enum.to_list(stream)) == 1
    end

    test "explicit :llm opt overrides the shim and is used directly" do
      assert {:ok, stream} =
               LeXtract.extract(
                 "Test text",
                 prompt: "Extract",
                 llm: {LeXtract.LLM.Stub, canned_text: "extractions: []\n"}
               )

      [doc] = Enum.to_list(stream)
      assert doc.text == "Test text"
      assert doc.extractions == []
    end

    test "explicit :llm opt wins even when legacy provider/model keys are also present" do
      Annotator
      |> stub(:new, fn _template, {adapter, adapter_opts}, _opts ->
        assert adapter == LeXtract.LLM.Stub
        refute Keyword.has_key?(adapter_opts, :provider)
        refute Keyword.has_key?(adapter_opts, :model)

        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          llm_adapter: adapter,
          llm_opts: adapter_opts,
          max_concurrency: 8,
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(text: doc.text, document_id: doc.document_id, extractions: [])
        end)
      end)

      assert {:ok, _stream} =
               LeXtract.extract(
                 "Test",
                 prompt: "Extract",
                 provider: :openai,
                 model: "gpt-4o-mini",
                 llm: {LeXtract.LLM.Stub, canned_text: "extractions: []\n"}
               )
    end

    test "application config default is consulted when no :llm opt is given" do
      Application.put_env(:lextract, :llm, {LeXtract.LLM.Stub, canned_text: "extractions: []\n"})
      on_exit(fn -> Application.delete_env(:lextract, :llm) end)

      assert {:ok, stream} = LeXtract.extract("Test text", prompt: "Extract")

      [doc] = Enum.to_list(stream)
      assert doc.text == "Test text"
      assert doc.extractions == []
    end

    test "falls back to LeXtract.LLM.ReqLLM when no app config and no :llm opt" do
      Application.delete_env(:lextract, :llm)

      Annotator
      |> stub(:new, fn _template, {adapter, _adapter_opts}, _opts ->
        assert adapter == LeXtract.LLM.ReqLLM

        %Annotator{
          prompt_generator: %LeXtract.Prompting{
            template: %{description: "test", examples: []},
            format_handler: LeXtract.FormatHandler.new(:yaml)
          },
          format_handler: LeXtract.FormatHandler.new(:yaml),
          llm_adapter: adapter,
          llm_opts: [],
          max_concurrency: 8,
          use_structured_output: false
        }
      end)

      Annotator
      |> stub(:annotate_documents, fn _annotator, documents, _opts ->
        Stream.map(documents, fn doc ->
          AnnotatedDocument.new(text: doc.text, document_id: doc.document_id, extractions: [])
        end)
      end)

      assert {:ok, _stream} =
               LeXtract.extract(
                 "Test",
                 prompt: "Extract",
                 provider: :openai,
                 model: "gpt-4o-mini"
               )
    end

    test "adapter validate_opts/1 error surfaces from extract/2" do
      assert {:error, error} =
               LeXtract.extract("Test", prompt: "Extract", llm: LeXtract.LLM.ReqLLM)

      assert %LeXtract.Error.Invalid.Config{} = error
    end
  end
end
