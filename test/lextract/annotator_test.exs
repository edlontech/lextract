defmodule LeXtract.AnnotatorTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias LeXtract.{AnnotatedDocument, Annotator, Document}
  alias LeXtract.LLM.Stub

  doctest LeXtract.Annotator

  describe "new/3" do
    test "creates annotator with required config" do
      template = %{
        description: "Extract entities",
        examples: []
      }

      llm_opts = [canned_text: "[]"]

      annotator = Annotator.new(template, {Stub, llm_opts})

      assert is_struct(annotator, Annotator)
      assert annotator.format_handler.format == :yaml
      assert annotator.llm_adapter == Stub
      assert annotator.llm_opts == llm_opts
      assert annotator.max_concurrency == 8
    end

    test "accepts format options" do
      template = %{description: "Test", examples: []}

      annotator = Annotator.new(template, {Stub, []}, format: :json)

      assert annotator.format_handler.format == :json
    end

    test "accepts fence_output option" do
      template = %{description: "Test", examples: []}

      annotator = Annotator.new(template, {Stub, []}, fence_output: true)

      assert annotator.format_handler.fence_output == true
    end

    test "accepts attribute_suffix option" do
      template = %{description: "Test", examples: []}

      annotator = Annotator.new(template, {Stub, []}, attribute_suffix: "_attrs")

      assert annotator.format_handler.attribute_suffix == "_attrs"
    end

    test "accepts max_concurrency option" do
      template = %{description: "Test", examples: []}

      annotator = Annotator.new(template, {Stub, []}, max_concurrency: 2)

      assert annotator.max_concurrency == 2
    end
  end

  describe "annotate_text/3" do
    test "annotates simple text with stubbed LLM" do
      template = %{
        description: "Extract people",
        examples: []
      }

      mock_llm_response = """
      [{"person": "John Doe", "person_index": 0}]
      """

      annotator =
        Annotator.new(template, {Stub, [canned_text: mock_llm_response]}, format: :json)

      doc = Annotator.annotate_text(annotator, "John Doe works here")

      assert %AnnotatedDocument{} = doc
      assert is_list(doc.extractions)
    end

    test "handles empty text" do
      template = %{description: "Extract", examples: []}
      annotator = Annotator.new(template, {Stub, [canned_text: "[]"]})

      doc = Annotator.annotate_text(annotator, "")

      assert %AnnotatedDocument{} = doc
      assert doc.extractions == []
    end

    test "handles text with no extractions" do
      template = %{description: "Extract", examples: []}
      annotator = Annotator.new(template, {Stub, [canned_text: "[]"]}, format: :json)

      doc = Annotator.annotate_text(annotator, "No entities here")

      assert doc.extractions == []
    end

    test "handles LLM response with multiple extractions" do
      template = %{description: "Extract", examples: []}

      mock_response = """
      [
        {"person": "John Doe", "person_index": 0},
        {"person": "Jane Smith", "person_index": 1}
      ]
      """

      annotator = Annotator.new(template, {Stub, [canned_text: mock_response]}, format: :json)

      doc = Annotator.annotate_text(annotator, "John Doe and Jane Smith work together")

      assert is_list(doc.extractions)
    end

    test "handles malformed LLM response gracefully" do
      template = %{description: "Extract", examples: []}

      annotator =
        Annotator.new(template, {Stub, [canned_text: "{invalid json}"]}, format: :json)

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
      annotator = Annotator.new(template, {Stub, [canned_text: "[]"]}, format: :json)

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
      annotator = Annotator.new(template, {Stub, [canned_text: "[]"]}, format: :json)

      doc = Document.create("Test", document_id: "my-doc-id")
      [annotated] = Annotator.annotate_documents(annotator, [doc]) |> Enum.to_list()

      assert annotated.document_id == "my-doc-id"
    end

    test "handles documents of varying lengths" do
      template = %{description: "Extract", examples: []}
      annotator = Annotator.new(template, {Stub, [canned_text: "[]"]}, format: :json)

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
      annotator = Annotator.new(template, {Stub, [canned_text: "[]"]}, format: :json)

      long_text = String.duplicate("Word ", 500)
      doc = Document.create(long_text)

      annotated =
        Annotator.annotate_documents(annotator, [doc], max_char_buffer: 100)
        |> Enum.to_list()

      assert length(annotated) == 1
    end

    test "supports batch_size option" do
      template = %{description: "Extract", examples: []}
      call_count = :counters.new(1, [:atomics])

      canned_text = fn ->
        :counters.add(call_count, 1, 1)
        "[]"
      end

      annotator = Annotator.new(template, {Stub, [canned_text: canned_text]}, format: :json)

      documents = Enum.map(1..10, fn i -> Document.create("Text #{i}") end)

      Annotator.annotate_documents(annotator, documents, batch_size: 5)
      |> Enum.to_list()

      assert :counters.get(call_count, 1) >= 2
    end
  end

  describe "multi-pass extraction" do
    test "runs multiple extraction passes" do
      template = %{description: "Extract", examples: []}
      call_count = :counters.new(1, [:atomics])

      canned_text = fn ->
        :counters.add(call_count, 1, 1)
        "[]"
      end

      annotator = Annotator.new(template, {Stub, [canned_text: canned_text]}, format: :json)

      doc = Document.create("Test text")

      Annotator.annotate_documents(annotator, [doc], extraction_passes: 3)
      |> Enum.to_list()

      assert :counters.get(call_count, 1) == 3
    end

    test "merges non-overlapping extractions from multiple passes" do
      template = %{description: "Extract", examples: []}
      pass_num = :counters.new(1, [:atomics])

      canned_text = fn ->
        current = :counters.get(pass_num, 1)
        :counters.add(pass_num, 1, 1)

        case current do
          0 -> ~s([{"entity": "first", "entity_index": 0}])
          1 -> ~s([{"entity": "second", "entity_index": 1}])
          _ -> "[]"
        end
      end

      annotator = Annotator.new(template, {Stub, [canned_text: canned_text]}, format: :json)

      doc = Document.create("Test first second")

      [annotated] =
        Annotator.annotate_documents(annotator, [doc], extraction_passes: 2)
        |> Enum.to_list()

      assert is_list(annotated.extractions)
    end
  end

  describe "error handling" do
    test "handles LLM inference errors gracefully" do
      template = %{description: "Extract", examples: []}
      annotator = Annotator.new(template, {Stub, [error: :network_error]})

      capture_log(fn ->
        doc = Annotator.annotate_text(annotator, "Test")

        assert %AnnotatedDocument{} = doc
        assert doc.extractions == []
      end)
    end

    test "handles alignment failures gracefully" do
      template = %{description: "Extract", examples: []}

      annotator =
        Annotator.new(
          template,
          {Stub, [canned_text: ~s([{"entity": "nonexistent"}])]},
          format: :json
        )

      doc = Annotator.annotate_text(annotator, "Different text")

      assert %AnnotatedDocument{} = doc
    end

    test "handles YAML format responses" do
      template = %{description: "Extract", examples: []}

      yaml_response = """
      - entity: test
        entity_index: 0
      """

      annotator = Annotator.new(template, {Stub, [canned_text: yaml_response]}, format: :yaml)

      doc = Annotator.annotate_text(annotator, "Test entity here")

      assert %AnnotatedDocument{} = doc
    end
  end

  describe "chunking and alignment" do
    test "handles long text with chunking" do
      template = %{description: "Extract", examples: []}
      annotator = Annotator.new(template, {Stub, [canned_text: "[]"]}, format: :json)

      long_text = String.duplicate("This is a test sentence. ", 100)
      doc = Annotator.annotate_text(annotator, long_text, max_char_buffer: 200)

      assert %AnnotatedDocument{} = doc
    end

    test "aligns extractions to correct positions in source text" do
      template = %{description: "Extract", examples: []}

      annotator =
        Annotator.new(
          template,
          {Stub, [canned_text: ~s([{"person": "John", "person_index": 0}])]},
          format: :json
        )

      doc = Annotator.annotate_text(annotator, "Hello John Doe")

      assert %AnnotatedDocument{} = doc

      if doc.extractions != [] do
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

      annotator = Annotator.new(template, {Stub, []}, use_structured_output: true)

      assert annotator.use_structured_output == true
    end

    test "defaults to text generation mode" do
      template = %{description: "Extract", examples: []}
      annotator = Annotator.new(template, {Stub, []})

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

      annotator =
        Annotator.new(template, {Stub, [canned_object: mock_object]}, use_structured_output: true)

      doc = Annotator.annotate_text(annotator, "Patient takes aspirin 100mg daily")

      assert %AnnotatedDocument{} = doc
      assert is_list(doc.extractions)
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

      annotator =
        Annotator.new(template, {Stub, [error: :network_error]}, use_structured_output: true)

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

      annotator =
        Annotator.new(template, {Stub, [canned_object: mock_object]}, use_structured_output: true)

      doc = Annotator.annotate_text(annotator, "Dr. Smith prescribed aspirin to patient")

      assert %AnnotatedDocument{} = doc
      assert is_list(doc.extractions)
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

      mock_object = %{"extractions" => []}

      annotator =
        Annotator.new(template, {Stub, [canned_object: mock_object]}, use_structured_output: true)

      doc = Annotator.annotate_text(annotator, "No medications here")

      assert %AnnotatedDocument{} = doc
      assert doc.extractions == []
    end
  end
end
