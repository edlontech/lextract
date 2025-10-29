defmodule LeXtract.TextChunkTest do
  use ExUnit.Case, async: true
  doctest LeXtract.TextChunk

  alias LeXtract.{CharInterval, Document, TextChunk, TokenInterval}

  describe "struct creation" do
    test "creates chunk with required text" do
      chunk = %TextChunk{text: "Sample text"}

      assert chunk.text == "Sample text"
      assert is_nil(chunk.document)
      assert is_nil(chunk.token_interval)
      assert is_nil(chunk.char_interval)
      assert is_nil(chunk.chunk_index)
    end

    test "creates chunk with optional fields" do
      doc = Document.create("Original document")
      char_interval = CharInterval.new(0, 10)
      token_interval = TokenInterval.new(0, 5)

      chunk = %TextChunk{
        text: "Sample text",
        document: doc,
        char_interval: char_interval,
        token_interval: token_interval,
        chunk_index: 0
      }

      assert chunk.text == "Sample text"
      assert chunk.document == doc
      assert chunk.char_interval == char_interval
      assert chunk.token_interval == token_interval
      assert chunk.chunk_index == 0
    end

    test "creates chunk with partial optional fields" do
      chunk = %TextChunk{text: "Sample text", chunk_index: 3}

      assert chunk.text == "Sample text"
      assert chunk.chunk_index == 3
      assert is_nil(chunk.document)
    end
  end

  describe "text_byte_size/1" do
    test "returns byte size of text" do
      chunk = %TextChunk{text: "Hello"}

      assert TextChunk.text_byte_size(chunk) == 5
    end

    test "returns correct byte size for empty string" do
      chunk = %TextChunk{text: ""}

      assert TextChunk.text_byte_size(chunk) == 0
    end

    test "returns correct byte size for UTF-8 text" do
      chunk = %TextChunk{text: "café"}

      assert TextChunk.text_byte_size(chunk) == 5
    end

    test "returns correct byte size for emoji" do
      chunk = %TextChunk{text: "👍"}

      assert TextChunk.text_byte_size(chunk) == 4
    end
  end

  describe "char_count/1" do
    test "returns character count" do
      chunk = %TextChunk{text: "Hello"}

      assert TextChunk.char_count(chunk) == 5
    end

    test "returns 0 for empty string" do
      chunk = %TextChunk{text: ""}

      assert TextChunk.char_count(chunk) == 0
    end

    test "returns correct count for UTF-8 text" do
      chunk = %TextChunk{text: "café"}

      assert TextChunk.char_count(chunk) == 4
    end

    test "returns correct count for emoji" do
      chunk = %TextChunk{text: "👍"}

      assert TextChunk.char_count(chunk) == 1
    end

    test "returns correct count for multi-byte characters" do
      chunk = %TextChunk{text: "こんにちは"}

      assert TextChunk.char_count(chunk) == 5
    end
  end

  describe "struct fields" do
    test "enforces required text field" do
      assert_raise ArgumentError, fn ->
        struct!(TextChunk, [])
      end
    end

    test "allows all optional fields to be nil" do
      chunk = %TextChunk{text: "test"}

      assert chunk.text == "test"
      assert is_nil(chunk.document)
      assert is_nil(chunk.token_interval)
      assert is_nil(chunk.char_interval)
      assert is_nil(chunk.chunk_index)
    end
  end
end
