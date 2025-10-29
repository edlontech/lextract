defmodule LeXtract.DocumentTest do
  use ExUnit.Case, async: true
  doctest LeXtract.Document

  alias LeXtract.Document

  describe "create/2" do
    test "creates document with text" do
      doc = Document.create("Sample text")

      assert doc.text == "Sample text"
      assert String.length(doc.document_id) == 36
      assert is_nil(doc.additional_context)
      assert is_nil(doc.metadata)
    end

    test "generates unique document IDs" do
      doc1 = Document.create("Text 1")
      doc2 = Document.create("Text 2")

      assert doc1.document_id != doc2.document_id
    end

    test "accepts custom document_id" do
      doc = Document.create("Sample text", document_id: "custom-id")

      assert doc.document_id == "custom-id"
    end

    test "accepts additional_context" do
      doc = Document.create("Sample text", additional_context: "Extra context")

      assert doc.additional_context == "Extra context"
    end

    test "accepts metadata" do
      metadata = %{author: "John", date: "2024-01-01"}
      doc = Document.create("Sample text", metadata: metadata)

      assert doc.metadata == metadata
    end

    test "accepts all optional fields" do
      metadata = %{type: "medical"}

      doc =
        Document.create("Sample text",
          document_id: "doc-123",
          additional_context: "Context",
          metadata: metadata
        )

      assert doc.text == "Sample text"
      assert doc.document_id == "doc-123"
      assert doc.additional_context == "Context"
      assert doc.metadata == metadata
    end
  end

  describe "from_texts/1" do
    test "creates multiple documents from list" do
      texts = ["Text 1", "Text 2", "Text 3"]
      docs = Document.from_texts(texts)

      assert length(docs) == 3
      assert Enum.at(docs, 0).text == "Text 1"
      assert Enum.at(docs, 1).text == "Text 2"
      assert Enum.at(docs, 2).text == "Text 3"
    end

    test "generates unique IDs for each document" do
      texts = ["Text 1", "Text 2"]
      docs = Document.from_texts(texts)

      [doc1, doc2] = docs
      assert doc1.document_id != doc2.document_id
    end

    test "handles empty list" do
      docs = Document.from_texts([])

      assert docs == []
    end

    test "handles single text" do
      docs = Document.from_texts(["Single text"])

      assert length(docs) == 1
      assert hd(docs).text == "Single text"
    end
  end

  describe "struct fields" do
    test "enforces required text field" do
      assert_raise ArgumentError, fn ->
        struct!(Document, [])
      end
    end

    test "allows empty string for text" do
      doc = Document.create("")

      assert doc.text == ""
    end
  end
end
