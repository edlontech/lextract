defmodule LeXtract.TextChunk do
  @moduledoc """
  Represents a chunk of text from a document, used for processing long documents.

  ## Fields

  * `:text` - The chunk text content
  * `:document` - Reference to source document
  * `:token_interval` - Token range in original document
  * `:char_interval` - Character range in original document
  * `:chunk_index` - Position in sequence of chunks

  ## Examples

      iex> chunk = %LeXtract.TextChunk{
      ...>   text: "Sample chunk",
      ...>   chunk_index: 0
      ...> }
      iex> chunk.chunk_index
      0

  """

  alias LeXtract.{CharInterval, Document, TokenInterval}

  @type t :: %__MODULE__{
          text: String.t(),
          document: Document.t() | nil,
          token_interval: TokenInterval.t() | nil,
          char_interval: CharInterval.t() | nil,
          chunk_index: non_neg_integer() | nil
        }

  @enforce_keys [:text]
  defstruct [:text, :document, :token_interval, :char_interval, :chunk_index]

  @doc """
  Returns the byte size of the chunk text.

  ## Examples

      iex> chunk = %LeXtract.TextChunk{text: "Hello"}
      iex> LeXtract.TextChunk.text_byte_size(chunk)
      5

  """
  @spec text_byte_size(t()) :: non_neg_integer()
  def text_byte_size(%__MODULE__{text: text}), do: byte_size(text)

  @doc """
  Returns the character count of the chunk text.

  ## Examples

      iex> chunk = %LeXtract.TextChunk{text: "Hello"}
      iex> LeXtract.TextChunk.char_count(chunk)
      5

  """
  @spec char_count(t()) :: non_neg_integer()
  def char_count(%__MODULE__{text: text}), do: String.length(text)
end
