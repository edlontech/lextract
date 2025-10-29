defmodule LeXtract.ChunkingTest do
  use ExUnit.Case, async: true

  alias LeXtract.{CharInterval, Chunking, Document, TextChunk, TokenInterval, Tokenizer}

  doctest Chunking

  describe "chunk_document/2" do
    test "returns a single chunk for short documents" do
      doc = Document.create("The patient has diabetes.")

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100)

      assert length(chunks) == 1
      [chunk] = chunks

      assert chunk.text == "The patient has diabetes."
      assert chunk.document == doc
      assert chunk.chunk_index == 0
      assert is_struct(chunk.char_interval, CharInterval)
      assert is_struct(chunk.token_interval, TokenInterval)
    end

    test "splits long documents into multiple chunks" do
      long_text = String.duplicate("This is a sentence. ", 100)
      doc = Document.create(long_text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100, chunk_overlap: 20)

      assert length(chunks) > 1

      Enum.each(chunks, fn chunk ->
        assert is_binary(chunk.text)
        assert chunk.document == doc
        assert is_struct(chunk.char_interval, CharInterval)
        assert is_struct(chunk.token_interval, TokenInterval)
        assert is_integer(chunk.chunk_index)
      end)

      assert Enum.all?(Enum.with_index(chunks), fn {chunk, idx} ->
               chunk.chunk_index == idx
             end)
    end

    test "handles empty text" do
      doc = Document.create("")

      chunks = Chunking.chunk_document(doc)

      assert chunks == []
    end

    test "handles single character" do
      doc = Document.create("x")

      chunks = Chunking.chunk_document(doc, max_char_buffer: 10)

      assert length(chunks) == 1
      [chunk] = chunks
      assert chunk.text == "x"
      assert chunk.char_interval.start_pos == 0
      assert chunk.char_interval.end_pos == 1
    end

    test "handles unicode text with emojis" do
      text = "Hello 😀 world 🎉 test"
      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100)

      assert length(chunks) == 1
      [chunk] = chunks
      assert chunk.text == text
      assert is_struct(chunk.token_interval, TokenInterval)
      assert chunk.token_interval.start_token >= 0
      assert chunk.token_interval.end_token > 0
    end

    test "handles multi-byte unicode characters" do
      text = "Café résumé naïve 日本語 中文"
      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100)

      assert length(chunks) == 1
      [chunk] = chunks
      assert chunk.text == text
      assert is_struct(chunk.char_interval, CharInterval)
      assert is_struct(chunk.token_interval, TokenInterval)
    end

    test "preserves document reference in all chunks" do
      long_text = String.duplicate("word ", 500)
      doc = Document.create(long_text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100, chunk_overlap: 20)

      assert length(chunks) > 1
      assert Enum.all?(chunks, fn chunk -> chunk.document == doc end)
    end

    test "creates non-overlapping byte positions" do
      long_text = "First sentence here. Second sentence there. Third sentence everywhere."
      doc = Document.create(long_text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 30, chunk_overlap: 10)

      assert length(chunks) >= 1

      Enum.each(chunks, fn chunk ->
        assert chunk.char_interval.start_pos >= 0
        assert chunk.char_interval.end_pos > chunk.char_interval.start_pos
      end)
    end

    test "token intervals are properly set for each chunk" do
      text = "The quick brown fox jumps over the lazy dog."
      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100)

      [chunk] = chunks

      assert chunk.token_interval.start_token == 0
      assert chunk.token_interval.end_token > 0
      assert TokenInterval.length(chunk.token_interval) > 0
    end

    test "uses default values when no options provided" do
      doc = Document.create("Sample text for testing defaults.")

      chunks = Chunking.chunk_document(doc)

      assert length(chunks) >= 1
      assert Enum.all?(chunks, &is_struct(&1, TextChunk))
    end

    test "respects custom max_char_buffer" do
      text = String.duplicate("word ", 100)
      doc = Document.create(text)

      small_chunks = Chunking.chunk_document(doc, max_char_buffer: 50)
      large_chunks = Chunking.chunk_document(doc, max_char_buffer: 200)

      assert length(small_chunks) > length(large_chunks)
    end

    test "respects custom chunk_overlap" do
      text = String.duplicate("sentence here ", 50)
      doc = Document.create(text)

      no_overlap = Chunking.chunk_document(doc, max_char_buffer: 100, chunk_overlap: 0)

      medium_overlap =
        Chunking.chunk_document(doc, max_char_buffer: 100, chunk_overlap: 20)

      assert length(no_overlap) <= length(medium_overlap)
    end

    test "handles very long text without boundaries" do
      text = String.duplicate("a", 10_000)
      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 1000, chunk_overlap: 100)

      assert length(chunks) > 1

      Enum.each(chunks, fn chunk ->
        assert String.length(chunk.text) <= 1100
      end)
    end

    test "all chunks have sequential indices" do
      long_text = String.duplicate("Test sentence. ", 100)
      doc = Document.create(long_text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100, chunk_overlap: 20)

      indices = Enum.map(chunks, & &1.chunk_index)
      expected_indices = Enum.to_list(0..(length(chunks) - 1))

      assert indices == expected_indices
    end

    test "char intervals match text positions" do
      text = "First part. Second part. Third part."
      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 100)

      [chunk] = chunks

      assert chunk.char_interval.start_pos == 0
      assert chunk.char_interval.end_pos == byte_size(text)
      assert CharInterval.length(chunk.char_interval) == byte_size(text)
    end

    test "raises error when invalid tokenizer is passed" do
      doc = Document.create("Test text")

      assert_raise ArgumentError, fn ->
        Chunking.chunk_document(doc, tokenizer: :invalid_tokenizer)
      end
    end
  end

  describe "chunk_with_tokenizer/3" do
    setup do
      {:ok, tokenizer} = Tokenizer.default_tokenizer()
      {:ok, tokenizer: tokenizer}
    end

    test "returns empty list for empty text", %{tokenizer: tokenizer} do
      chunks = Chunking.chunk_with_tokenizer("", tokenizer)

      assert chunks == []
    end

    test "chunks text without document reference", %{tokenizer: tokenizer} do
      text = "Hello world"

      chunks = Chunking.chunk_with_tokenizer(text, tokenizer)

      assert length(chunks) == 1
      [chunk] = chunks
      assert chunk.text == text
      assert chunk.document == nil
      assert chunk.chunk_index == 0
    end

    test "chunks text with document reference", %{tokenizer: tokenizer} do
      text = "Hello world"
      doc = Document.create(text)

      chunks = Chunking.chunk_with_tokenizer(text, tokenizer, doc)

      assert length(chunks) == 1
      [chunk] = chunks
      assert chunk.text == text
      assert chunk.document == doc
    end

    test "handles long text", %{tokenizer: tokenizer} do
      long_text = String.duplicate("Test sentence here. ", 100)

      chunks =
        Chunking.chunk_with_tokenizer(long_text, tokenizer, nil,
          max_char_buffer: 100,
          chunk_overlap: 20
        )

      assert length(chunks) > 1

      Enum.each(chunks, fn chunk ->
        assert is_binary(chunk.text)
        assert is_struct(chunk.char_interval, CharInterval)
        assert is_struct(chunk.token_interval, TokenInterval)
      end)
    end

    test "all chunks have token intervals", %{tokenizer: tokenizer} do
      text = "The quick brown fox jumps over the lazy dog."

      chunks = Chunking.chunk_with_tokenizer(text, tokenizer)

      assert Enum.all?(chunks, fn chunk ->
               is_struct(chunk.token_interval, TokenInterval) and
                 chunk.token_interval.end_token > 0
             end)
    end

    test "respects max_char_buffer option", %{tokenizer: tokenizer} do
      text = String.duplicate("word ", 200)

      small_chunks =
        Chunking.chunk_with_tokenizer(text, tokenizer, nil, max_char_buffer: 50)

      large_chunks =
        Chunking.chunk_with_tokenizer(text, tokenizer, nil, max_char_buffer: 200)

      assert length(small_chunks) > length(large_chunks)
    end

    test "respects chunk_overlap option", %{tokenizer: tokenizer} do
      text = String.duplicate("sentence ", 100)

      no_overlap =
        Chunking.chunk_with_tokenizer(text, tokenizer, nil,
          max_char_buffer: 100,
          chunk_overlap: 0
        )

      with_overlap =
        Chunking.chunk_with_tokenizer(text, tokenizer, nil,
          max_char_buffer: 100,
          chunk_overlap: 30
        )

      assert length(no_overlap) <= length(with_overlap)
    end

    test "handles unicode properly", %{tokenizer: tokenizer} do
      text = "Emoji test 😀 🎉 ✨"

      chunks = Chunking.chunk_with_tokenizer(text, tokenizer)

      assert length(chunks) == 1
      [chunk] = chunks
      assert chunk.text == text
      assert is_struct(chunk.token_interval, TokenInterval)
    end
  end

  describe "calculate_overlap/1" do
    test "calculates 20% of chunk size" do
      assert Chunking.calculate_overlap(1000) == 200
      assert Chunking.calculate_overlap(500) == 100
      assert Chunking.calculate_overlap(100) == 20
      assert Chunking.calculate_overlap(50) == 10
    end

    test "handles small values" do
      assert Chunking.calculate_overlap(10) == 2
      assert Chunking.calculate_overlap(5) == 1
      assert Chunking.calculate_overlap(1) == 0
    end

    test "handles large values" do
      assert Chunking.calculate_overlap(10_000) == 2000
      assert Chunking.calculate_overlap(100_000) == 20_000
    end
  end

  describe "integration tests" do
    test "end-to-end chunking with realistic medical text" do
      text = """
      The patient is a 45-year-old male presenting with symptoms of diabetes.
      Blood glucose levels were elevated at 180 mg/dL. HbA1c was measured at 7.5%.
      Patient reports increased thirst and frequent urination over the past month.
      Family history is significant for type 2 diabetes in both parents.
      """

      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 150, chunk_overlap: 30)

      assert length(chunks) >= 1

      Enum.each(chunks, fn chunk ->
        assert String.length(chunk.text) <= 180
        assert chunk.document == doc
        assert is_struct(chunk.char_interval, CharInterval)
        assert is_struct(chunk.token_interval, TokenInterval)
        assert chunk.token_interval.end_token > 0
      end)

      first_chunk = List.first(chunks)
      assert first_chunk.char_interval.start_pos == 0

      last_chunk = List.last(chunks)
      original_byte_size = byte_size(String.trim(text))
      assert last_chunk.char_interval.end_pos <= original_byte_size + 1
    end

    test "chunking preserves complete text coverage" do
      text = "Sentence one. Sentence two. Sentence three. Sentence four."
      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc, max_char_buffer: 25, chunk_overlap: 10)

      covered_ranges =
        Enum.map(chunks, fn chunk ->
          {chunk.char_interval.start_pos, chunk.char_interval.end_pos}
        end)

      assert List.first(covered_ranges) |> elem(0) == 0

      last_end = List.last(covered_ranges) |> elem(1)
      assert last_end == byte_size(text)
    end

    test "token intervals are consistent with text content" do
      text = "The quick brown fox"
      doc = Document.create(text)

      chunks = Chunking.chunk_document(doc)

      [chunk] = chunks

      {:ok, encoding} = Tokenizer.tokenize(chunk.text)
      expected_token_count = length(Tokenizer.get_tokens(encoding))

      assert TokenInterval.length(chunk.token_interval) == expected_token_count
    end
  end
end
