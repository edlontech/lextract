defmodule LeXtract.Document do
  @moduledoc """
  Represents an input document for information extraction.

  ## Fields

  * `:text` - Raw text content of the document
  * `:additional_context` - Extra context provided to LLM (not part of main text)
  * `:document_id` - Unique identifier (auto-generated if not provided)
  * `:metadata` - Optional metadata about the document

  ## Examples

      iex> doc = LeXtract.Document.create("The patient has diabetes.")
      iex> doc.text
      "The patient has diabetes."

  """

  @type example :: %{
          text: String.t(),
          extractions: [map()]
        }

  @type t :: %__MODULE__{
          text: String.t(),
          additional_context: String.t() | nil,
          document_id: String.t(),
          metadata: map() | nil
        }

  @enforce_keys [:text]
  defstruct [:text, :additional_context, :document_id, :metadata]

  @doc """
  Creates a new document with the given text.

  Automatically generates a UUID if `document_id` is not provided.

  ## Examples

      iex> doc = LeXtract.Document.create("Sample text")
      iex> String.length(doc.document_id)
      36

  """
  @spec create(String.t(), keyword()) :: t()
  def create(text, opts \\ []) do
    document_id = Keyword.get(opts, :document_id, UUIDv7.generate())

    struct!(__MODULE__,
      text: text,
      document_id: document_id,
      additional_context: Keyword.get(opts, :additional_context),
      metadata: Keyword.get(opts, :metadata)
    )
  end

  @doc """
  Creates multiple documents from a list of texts.

  ## Examples

      iex> docs = LeXtract.Document.from_texts(["Text 1", "Text 2"])
      iex> length(docs)
      2

  """
  @spec from_texts([String.t()]) :: [t()]
  def from_texts(texts) when is_list(texts) do
    Enum.map(texts, &create/1)
  end
end
