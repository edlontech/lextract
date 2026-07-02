defmodule LeXtract.Chunking do
  @moduledoc """
  Integrates semantic text chunking with tokenization for document processing.

  This module combines TextChunker's semantic splitting capabilities with
  LeXtract's tokenization system to produce chunks that maintain both
  character-level and token-level position information.

  ## Key Features

  * Semantic boundary detection via TextChunker
  * Token-level position tracking for each chunk
  * Configurable chunk sizes and overlap
  * Unicode-aware processing (handles emojis and multi-byte characters)
  * Byte-level accuracy for text alignment

  ## Options

  * `:max_char_buffer` - Maximum chunk size in characters (default: 1000)
  * `:chunk_overlap` - Overlap between chunks in characters (default: 200)
  * `:tokenizer` - Custom tokenizer instance (default: uses `LeXtract.Tokenizer.default_tokenizer/0`)

  ## Examples

      iex> doc = LeXtract.Document.create("The patient has diabetes. The patient is 45 years old.")
      iex> chunks = LeXtract.Chunking.chunk_document(doc)
      iex> length(chunks) >= 1
      true

      iex> doc = LeXtract.Document.create("Short text")
      iex> [chunk] = LeXtract.Chunking.chunk_document(doc, max_char_buffer: 100)
      iex> chunk.text
      "Short text"

      iex> long_text = String.duplicate("word ", 500)
      iex> doc = LeXtract.Document.create(long_text)
      iex> chunks = LeXtract.Chunking.chunk_document(doc, max_char_buffer: 100, chunk_overlap: 20)
      iex> length(chunks) > 1
      true

  """

  alias LeXtract.{CharInterval, Document, TextChunk, TokenInterval, Tokenizer}

  @default_max_char_buffer 1000
  @default_chunk_overlap 200

  @doc """
  Chunks a document using semantic splitting and tokenization.

  Takes a Document and splits its text into smaller TextChunks, each containing:
  - The chunk text
  - Byte positions (start_byte, end_byte) from TextChunker
  - Token information via Tokenizer encoding
  - Character and token intervals for alignment

  ## Options

  * `:max_char_buffer` - Maximum chunk size in characters (default: #{@default_max_char_buffer})
  * `:chunk_overlap` - Overlap between chunks in characters (default: #{@default_chunk_overlap})
  * `:tokenizer` - Custom tokenizer instance (default: uses `LeXtract.Tokenizer.default_tokenizer/0`)

  ## Examples

      iex> doc = LeXtract.Document.create("Hello world")
      iex> chunks = LeXtract.Chunking.chunk_document(doc)
      iex> [chunk] = chunks
      iex> chunk.text
      "Hello world"
      iex> is_struct(chunk.char_interval, LeXtract.CharInterval)
      true
      iex> is_struct(chunk.token_interval, LeXtract.TokenInterval)
      true

      iex> doc = LeXtract.Document.create("")
      iex> LeXtract.Chunking.chunk_document(doc)
      []

  """
  @spec chunk_document(Document.t(), keyword()) :: [TextChunk.t()]
  def chunk_document(%Document{text: text} = document, opts \\ []) do
    max_char_buffer = Keyword.get(opts, :max_char_buffer, @default_max_char_buffer)
    chunk_overlap = Keyword.get(opts, :chunk_overlap, @default_chunk_overlap)

    case get_tokenizer(opts) do
      {:ok, tokenizer} ->
        chunk_with_tokenizer(text, tokenizer, document,
          max_char_buffer: max_char_buffer,
          chunk_overlap: chunk_overlap
        )

      {:error, %LeXtract.Error.External.TokenizerLoad{} = error} ->
        raise error

      {:error, reason} ->
        raise LeXtract.Error.Processing.Chunking.exception(
                reason: "Failed to load tokenizer: #{inspect(reason)}"
              )
    end
  end

  @doc """
  Chunks text with a specific tokenizer instance and optional document reference.

  This function performs the core chunking logic:
  1. Splits text using TextChunker for semantic boundaries
  2. Tokenizes each chunk to get token offsets
  3. Creates TextChunk structs with both character and token intervals

  ## Options

  * `:max_char_buffer` - Maximum chunk size in characters (default: #{@default_max_char_buffer})
  * `:chunk_overlap` - Overlap between chunks in characters (default: #{@default_chunk_overlap})

  ## Examples

      iex> {:ok, tokenizer} = LeXtract.Tokenizer.default_tokenizer()
      iex> chunks = LeXtract.Chunking.chunk_with_tokenizer("Hello world", tokenizer)
      iex> [chunk] = chunks
      iex> chunk.text
      "Hello world"

      iex> {:ok, tokenizer} = LeXtract.Tokenizer.default_tokenizer()
      iex> LeXtract.Chunking.chunk_with_tokenizer("", tokenizer)
      []

  """
  @spec chunk_with_tokenizer(String.t(), Tokenizer.tokenizer_ref(), Document.t() | nil, keyword()) ::
          [TextChunk.t()]
  def chunk_with_tokenizer(text, tokenizer, document \\ nil, opts \\ [])

  def chunk_with_tokenizer("", _tokenizer, _document, _opts), do: []

  def chunk_with_tokenizer(text, tokenizer, document, opts) when is_binary(text) do
    max_char_buffer = Keyword.get(opts, :max_char_buffer, @default_max_char_buffer)
    chunk_overlap = Keyword.get(opts, :chunk_overlap, @default_chunk_overlap)

    text_chunks =
      TextChunker.split(text,
        chunk_size: max_char_buffer,
        chunk_overlap: chunk_overlap
      )

    text_chunks
    |> Enum.with_index()
    |> Enum.map(fn {tc_chunk, index} ->
      create_text_chunk(tc_chunk, tokenizer, document, index)
    end)
  end

  @doc """
  Calculates optimal overlap as 20% of the chunk size.

  ## Examples

      iex> LeXtract.Chunking.calculate_overlap(1000)
      200

      iex> LeXtract.Chunking.calculate_overlap(500)
      100

      iex> LeXtract.Chunking.calculate_overlap(10)
      2

  """
  @spec calculate_overlap(pos_integer()) :: pos_integer()
  def calculate_overlap(chunk_size) when is_integer(chunk_size) and chunk_size > 0 do
    div(chunk_size * 20, 100)
  end

  defp get_tokenizer(opts) do
    case Keyword.get(opts, :tokenizer) do
      nil -> Tokenizer.default_tokenizer()
      tokenizer -> {:ok, tokenizer}
    end
  end

  defp create_text_chunk(tc_chunk, tokenizer, document, index) do
    %TextChunker.Chunk{
      text: chunk_text,
      start_byte: start_byte,
      end_byte: end_byte
    } = tc_chunk

    {:ok, encoding} = Tokenizers.Tokenizer.encode(tokenizer, chunk_text)

    offsets = Tokenizers.Encoding.get_offsets(encoding)

    token_interval =
      if offsets == [] do
        TokenInterval.new(0, 0)
      else
        TokenInterval.new(0, length(offsets))
      end

    char_interval = CharInterval.new(start_byte, end_byte)

    %TextChunk{
      text: chunk_text,
      document: document,
      token_interval: token_interval,
      char_interval: char_interval,
      chunk_index: index
    }
  end
end
