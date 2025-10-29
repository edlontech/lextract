defmodule LeXtract.AnnotatedDocumentTest do
  use ExUnit.Case, async: true
  doctest LeXtract.AnnotatedDocument

  alias LeXtract.{AnnotatedDocument, Extraction}

  describe "struct creation" do
    test "creates annotated document with required document_id" do
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: []}

      assert doc.document_id == "doc-1"
      assert doc.extractions == []
      assert is_nil(doc.text)
      assert is_nil(doc.metadata)
    end

    test "creates annotated document with extractions" do
      extractions = [
        %Extraction{extraction_class: "person", extraction_text: "John Doe"},
        %Extraction{extraction_class: "medication", extraction_text: "aspirin"}
      ]

      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}

      assert doc.document_id == "doc-1"
      assert length(doc.extractions) == 2
    end

    test "accepts optional text" do
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: [], text: "Sample text"}

      assert doc.text == "Sample text"
    end

    test "accepts optional metadata" do
      metadata = %{source: "test", timestamp: "2024-01-01"}
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: [], metadata: metadata}

      assert doc.metadata == metadata
    end

    test "accepts all optional fields" do
      extractions = [%Extraction{extraction_class: "person", extraction_text: "John"}]
      metadata = %{version: "1.0"}

      doc = %AnnotatedDocument{
        document_id: "doc-1",
        extractions: extractions,
        text: "Sample text",
        metadata: metadata
      }

      assert doc.document_id == "doc-1"
      assert length(doc.extractions) == 1
      assert doc.text == "Sample text"
      assert doc.metadata == metadata
    end
  end

  describe "by_class/2" do
    setup do
      extractions = [
        %Extraction{extraction_class: "person", extraction_text: "John Doe"},
        %Extraction{extraction_class: "person", extraction_text: "Jane Smith"},
        %Extraction{extraction_class: "medication", extraction_text: "aspirin"},
        %Extraction{extraction_class: "condition", extraction_text: "diabetes"}
      ]

      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}

      {:ok, doc: doc}
    end

    test "filters extractions by class", %{doc: doc} do
      persons = AnnotatedDocument.by_class(doc, "person")

      assert length(persons) == 2
      assert Enum.all?(persons, &(&1.extraction_class == "person"))
    end

    test "returns single extraction for unique class", %{doc: doc} do
      conditions = AnnotatedDocument.by_class(doc, "condition")

      assert length(conditions) == 1
      assert hd(conditions).extraction_text == "diabetes"
    end

    test "returns empty list for non-existent class", %{doc: doc} do
      results = AnnotatedDocument.by_class(doc, "location")

      assert results == []
    end

    test "returns empty list for empty document" do
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: []}
      results = AnnotatedDocument.by_class(doc, "person")

      assert results == []
    end
  end

  describe "extraction_classes/1" do
    test "returns all unique classes" do
      extractions = [
        %Extraction{extraction_class: "person", extraction_text: "John"},
        %Extraction{extraction_class: "person", extraction_text: "Jane"},
        %Extraction{extraction_class: "medication", extraction_text: "aspirin"},
        %Extraction{extraction_class: "condition", extraction_text: "diabetes"}
      ]

      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}
      classes = AnnotatedDocument.extraction_classes(doc)

      assert classes == ["condition", "medication", "person"]
    end

    test "returns sorted classes" do
      extractions = [
        %Extraction{extraction_class: "zebra", extraction_text: "text1"},
        %Extraction{extraction_class: "alpha", extraction_text: "text2"},
        %Extraction{extraction_class: "middle", extraction_text: "text3"}
      ]

      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}
      classes = AnnotatedDocument.extraction_classes(doc)

      assert classes == ["alpha", "middle", "zebra"]
    end

    test "returns empty list for no extractions" do
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: []}
      classes = AnnotatedDocument.extraction_classes(doc)

      assert classes == []
    end

    test "handles single extraction" do
      extractions = [%Extraction{extraction_class: "person", extraction_text: "John"}]
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}
      classes = AnnotatedDocument.extraction_classes(doc)

      assert classes == ["person"]
    end
  end

  describe "count/1" do
    test "returns count of extractions" do
      extractions = [
        %Extraction{extraction_class: "person", extraction_text: "John"},
        %Extraction{extraction_class: "medication", extraction_text: "aspirin"}
      ]

      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}

      assert AnnotatedDocument.count(doc) == 2
    end

    test "returns 0 for empty extractions" do
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: []}

      assert AnnotatedDocument.count(doc) == 0
    end

    test "returns correct count for many extractions" do
      extractions =
        Enum.map(1..100, fn i ->
          %Extraction{extraction_class: "entity", extraction_text: "text-#{i}"}
        end)

      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}

      assert AnnotatedDocument.count(doc) == 100
    end
  end

  describe "has_extractions?/1" do
    test "returns false for empty extractions" do
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: []}

      refute AnnotatedDocument.has_extractions?(doc)
    end

    test "returns true for non-empty extractions" do
      extractions = [%Extraction{extraction_class: "person", extraction_text: "John"}]
      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}

      assert AnnotatedDocument.has_extractions?(doc)
    end

    test "returns true for multiple extractions" do
      extractions = [
        %Extraction{extraction_class: "person", extraction_text: "John"},
        %Extraction{extraction_class: "medication", extraction_text: "aspirin"}
      ]

      doc = %AnnotatedDocument{document_id: "doc-1", extractions: extractions}

      assert AnnotatedDocument.has_extractions?(doc)
    end
  end

  describe "struct fields" do
    test "enforces required document_id field" do
      assert_raise ArgumentError, fn ->
        struct!(AnnotatedDocument, [])
      end
    end

    test "allows nil extractions to default to nil" do
      doc = %AnnotatedDocument{document_id: "doc-1"}

      assert is_nil(doc.extractions)
    end
  end

  describe "integration" do
    test "creates fully populated annotated document" do
      extractions = [
        %Extraction{
          extraction_class: "person",
          extraction_text: "John Doe",
          extraction_index: 0,
          attributes: %{age: "30"}
        },
        %Extraction{
          extraction_class: "medication",
          extraction_text: "aspirin",
          extraction_index: 1,
          attributes: %{dosage: "81mg"}
        }
      ]

      metadata = %{
        model: "gpt-4",
        timestamp: "2024-01-01",
        confidence: 0.95
      }

      doc = %AnnotatedDocument{
        document_id: "doc-123",
        extractions: extractions,
        text: "John Doe takes aspirin 81mg daily.",
        metadata: metadata
      }

      assert AnnotatedDocument.has_extractions?(doc)
      assert AnnotatedDocument.count(doc) == 2
      assert AnnotatedDocument.extraction_classes(doc) == ["medication", "person"]
      assert length(AnnotatedDocument.by_class(doc, "person")) == 1
      assert doc.metadata.model == "gpt-4"
    end
  end
end
