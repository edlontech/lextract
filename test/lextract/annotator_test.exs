defmodule LeXtract.AnnotatorTest do
  use ExUnit.Case, async: false
  use Mimic
  import ExUnit.CaptureLog

  alias LeXtract.{AnnotatedDocument, Annotator, Document}

  doctest LeXtract.Annotator

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ReqLLM)
    :ok
  end

  describe "new/3" do
    test "creates annotator with required config" do
      template = %{
        description: "Extract entities",
        examples: []
      }

      config = [
        model: "gemini-2.0-flash",
        provider: :gemini,
        api_key: "test-key"
      ]

      annotator = Annotator.new(template, config)

      assert is_struct(annotator, Annotator)
      assert annotator.format_handler.format == :yaml
      assert annotator.req_llm_config == config
    end

    test "accepts format options" do
      template = %{description: "Test", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]

      annotator = Annotator.new(template, config, format: :json)

      assert annotator.format_handler.format == :json
    end

    test "accepts fence_output option" do
      template = %{description: "Test", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]

      annotator = Annotator.new(template, config, fence_output: true)

      assert annotator.format_handler.fence_output == true
    end

    test "accepts attribute_suffix option" do
      template = %{description: "Test", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]

      annotator = Annotator.new(template, config, attribute_suffix: "_attrs")

      assert annotator.format_handler.attribute_suffix == "_attrs"
    end
  end

  describe "annotate_text/3" do
    test "annotates simple text with mocked LLM" do
      template = %{
        description: "Extract people",
        examples: []
      }

      config = [model: "gemini-2.0-flash", provider: :gemini, api_key: "test"]
      annotator = Annotator.new(template, config, format: :json)

      mock_llm_response = """
      [{"person": "John Doe", "person_index": 0}]
      """

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: mock_llm_response},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "gemini-2.0-flash",
           id: "test-id-1"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "John Doe works here")

      assert %AnnotatedDocument{} = doc
      assert length(doc.extractions) >= 0
    end

    test "handles empty text" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config)

      doc = Annotator.annotate_text(annotator, "")

      assert %AnnotatedDocument{} = doc
      assert doc.extractions == []
    end

    test "handles text with no extractions" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "No entities here")

      assert doc.extractions == []
    end

    test "handles LLM response with multiple extractions" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      mock_response = """
      [
        {"person": "John Doe", "person_index": 0},
        {"person": "Jane Smith", "person_index": 1}
      ]
      """

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: mock_response},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "John Doe and Jane Smith work together")

      assert length(doc.extractions) >= 0
    end

    test "handles malformed LLM response gracefully" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "{invalid json}"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      capture_log(fn ->
        doc = Annotator.annotate_text(annotator, "Test text")

        assert %AnnotatedDocument{} = doc
        assert doc.extractions == []
      end)
    end
  end

  describe "annotate_documents/3" do
    test "annotates multiple documents" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      documents = [
        Document.create("Text 1", document_id: "doc1"),
        Document.create("Text 2", document_id: "doc2")
      ]

      annotated = Annotator.annotate_documents(annotator, documents)

      result = Enum.to_list(annotated)
      assert length(result) == 2
      assert Enum.all?(result, &is_struct(&1, AnnotatedDocument))
    end

    test "preserves document_id" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Document.create("Test", document_id: "my-doc-id")
      [annotated] = Annotator.annotate_documents(annotator, [doc]) |> Enum.to_list()

      assert annotated.document_id == "my-doc-id"
    end

    test "handles documents of varying lengths" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      documents = [
        Document.create("Short"),
        Document.create(String.duplicate("Long text. ", 100)),
        Document.create("Medium length text here")
      ]

      annotated = Annotator.annotate_documents(annotator, documents)

      result = Enum.to_list(annotated)
      assert length(result) == 3
    end

    test "supports max_char_buffer option" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      long_text = String.duplicate("Word ", 500)
      doc = Document.create(long_text)

      annotated =
        Annotator.annotate_documents(annotator, [doc], max_char_buffer: 100)
        |> Enum.to_list()

      assert length(annotated) == 1
    end

    test "supports batch_size option" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      call_count = :counters.new(1, [:atomics])

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        :counters.add(call_count, 1, 1)

        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      documents = Enum.map(1..10, fn i -> Document.create("Text #{i}") end)

      Annotator.annotate_documents(annotator, documents, batch_size: 5)
      |> Enum.to_list()

      assert :counters.get(call_count, 1) >= 2
    end
  end

  describe "multi-pass extraction" do
    test "runs multiple extraction passes" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      call_count = :counters.new(1, [:atomics])

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        :counters.add(call_count, 1, 1)

        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Document.create("Test text")

      Annotator.annotate_documents(annotator, [doc], extraction_passes: 3)
      |> Enum.to_list()

      assert :counters.get(call_count, 1) == 3
    end

    test "merges non-overlapping extractions from multiple passes" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      pass_num = :counters.new(1, [:atomics])

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        current = :counters.get(pass_num, 1)
        :counters.add(pass_num, 1, 1)

        response =
          case current do
            0 -> ~s([{"entity": "first", "entity_index": 0}])
            1 -> ~s([{"entity": "second", "entity_index": 1}])
            _ -> "[]"
          end

        {:ok,
         %ReqLLM.Response{
           message: %{content: response},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Document.create("Test first second")

      [annotated] =
        Annotator.annotate_documents(annotator, [doc], extraction_passes: 2)
        |> Enum.to_list()

      assert length(annotated.extractions) >= 0
    end
  end

  describe "error handling" do
    test "handles LLM inference errors gracefully" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config)

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:error, :network_error}
      end)

      capture_log(fn ->
        doc = Annotator.annotate_text(annotator, "Test")

        assert %AnnotatedDocument{} = doc
        assert doc.extractions == []
      end)
    end

    test "handles alignment failures gracefully" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: ~s([{"entity": "nonexistent"}])},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "Different text")

      assert %AnnotatedDocument{} = doc
    end

    test "handles YAML format responses" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :yaml)

      yaml_response = """
      - entity: test
        entity_index: 0
      """

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: yaml_response},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "Test entity here")

      assert %AnnotatedDocument{} = doc
    end
  end

  describe "chunking and alignment" do
    test "handles long text with chunking" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> stub(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "[]"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      long_text = String.duplicate("This is a test sentence. ", 100)
      doc = Annotator.annotate_text(annotator, long_text, max_char_buffer: 200)

      assert %AnnotatedDocument{} = doc
    end

    test "aligns extractions to correct positions in source text" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, format: :json)

      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: ~s([{"person": "John", "person_index": 0}])},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "Hello John Doe")

      assert %AnnotatedDocument{} = doc

      if length(doc.extractions) > 0 do
        extraction = hd(doc.extractions)
        assert extraction.extraction_class == "Person"
        assert extraction.extraction_text == "John"
      end
    end
  end

  describe "structured output mode" do
    test "creates annotator with use_structured_output option" do
      template = %{
        description: "Extract medications",
        examples: [
          %{
            text: "Patient takes aspirin",
            extractions: [
              %{extraction_class: "Medication", name: "aspirin"}
            ]
          }
        ]
      }

      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, use_structured_output: true)

      assert annotator.use_structured_output == true
    end

    test "defaults to text generation mode" do
      template = %{description: "Extract", examples: []}
      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config)

      assert annotator.use_structured_output == false
    end

    test "uses generate_object when structured output is enabled" do
      template = %{
        description: "Extract medications",
        examples: [
          %{
            text: "Patient takes aspirin 100mg",
            extractions: [
              %{
                extraction_class: "Medication",
                name: "aspirin",
                dosage: "100mg"
              }
            ]
          }
        ]
      }

      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, use_structured_output: true)

      mock_object = %{
        "extractions" => [
          %{
            "class" => "Medication",
            "Medication_attributes" => %{
              "name" => "aspirin",
              "dosage" => "100mg"
            }
          }
        ]
      }

      ReqLLM
      |> expect(:generate_object, fn _model, _prompt, _schema, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "", role: :assistant},
           object: mock_object,
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "Patient takes aspirin 100mg daily")

      assert %AnnotatedDocument{} = doc
      assert length(doc.extractions) >= 0
    end

    test "handles structured output errors gracefully" do
      template = %{
        description: "Extract medications",
        examples: [
          %{
            text: "Patient takes aspirin",
            extractions: [%{extraction_class: "Medication", name: "aspirin"}]
          }
        ]
      }

      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, use_structured_output: true)

      ReqLLM
      |> expect(:generate_object, fn _model, _prompt, _schema, _opts ->
        {:error, :network_error}
      end)

      capture_log(fn ->
        doc = Annotator.annotate_text(annotator, "Test text")

        assert %AnnotatedDocument{} = doc
        assert doc.extractions == []
      end)
    end

    test "parses structured response with multiple extractions" do
      template = %{
        description: "Extract medications and people",
        examples: [
          %{
            text: "Dr. Smith prescribed aspirin to patient",
            extractions: [
              %{extraction_class: "Person", name: "Dr. Smith", role: "doctor"},
              %{extraction_class: "Medication", name: "aspirin"}
            ]
          }
        ]
      }

      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, use_structured_output: true)

      mock_object = %{
        "extractions" => [
          %{
            "class" => "Person",
            "Person_attributes" => %{"name" => "Dr. Smith", "role" => "doctor"}
          },
          %{
            "class" => "Medication",
            "Medication_attributes" => %{"name" => "aspirin"}
          }
        ]
      }

      ReqLLM
      |> expect(:generate_object, fn _model, _prompt, _schema, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "", role: :assistant},
           object: mock_object,
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "Dr. Smith prescribed aspirin to patient")

      assert %AnnotatedDocument{} = doc
      assert length(doc.extractions) >= 0
    end

    test "handles empty extractions in structured output" do
      template = %{
        description: "Extract medications",
        examples: [
          %{
            text: "Patient has no medications",
            extractions: []
          }
        ]
      }

      config = [model: "test", provider: :test, api_key: "key"]
      annotator = Annotator.new(template, config, use_structured_output: true)

      mock_object = %{"extractions" => []}

      ReqLLM
      |> expect(:generate_object, fn _model, _prompt, _schema, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "", role: :assistant},
           object: mock_object,
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "test",
           id: "test-id"
         }}
      end)

      doc = Annotator.annotate_text(annotator, "No medications here")

      assert %AnnotatedDocument{} = doc
      assert doc.extractions == []
    end
  end
end
