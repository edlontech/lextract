defmodule LeXtract.AnnotatedDocument do
  @moduledoc """
  Represents a document with extracted entities and relationships.

  This is the primary output type from `LeXtract.extract/2`.

  ## Fields

  * `:extractions` - List of extracted entities
  * `:text` - Original document text
  * `:document_id` - Unique identifier
  * `:metadata` - Optional metadata about extraction process

  ## Examples

      iex> doc = %LeXtract.AnnotatedDocument{
      ...>   document_id: "abc-123",
      ...>   text: "Sample text",
      ...>   extractions: []
      ...> }
      iex> Enum.count(doc.extractions)
      0

  """

  alias LeXtract.Extraction

  @type t :: %__MODULE__{
          extractions: [Extraction.t()],
          text: String.t() | nil,
          document_id: String.t(),
          metadata: map() | nil
        }

  @enforce_keys [:document_id]
  defstruct [:extractions, :text, :document_id, :metadata]

  @doc """
  Returns extractions filtered by class.

  ## Examples

      iex> extractions = [
      ...>   %LeXtract.Extraction{extraction_class: "person", extraction_text: "John"},
      ...>   %LeXtract.Extraction{extraction_class: "medication", extraction_text: "aspirin"}
      ...> ]
      iex> doc = %LeXtract.AnnotatedDocument{document_id: "doc-1", extractions: extractions}
      iex> doc |> LeXtract.AnnotatedDocument.by_class("person") |> length()
      1

  """
  @spec by_class(t(), String.t()) :: [Extraction.t()]
  def by_class(%__MODULE__{extractions: extractions}, class) do
    Enum.filter(extractions, &(&1.extraction_class == class))
  end

  @doc """
  Returns all unique extraction classes.

  ## Examples

      iex> extractions = [
      ...>   %LeXtract.Extraction{extraction_class: "person", extraction_text: "John"},
      ...>   %LeXtract.Extraction{extraction_class: "person", extraction_text: "Jane"}
      ...> ]
      iex> doc = %LeXtract.AnnotatedDocument{document_id: "doc-1", extractions: extractions}
      iex> LeXtract.AnnotatedDocument.extraction_classes(doc)
      ["person"]

  """
  @spec extraction_classes(t()) :: [String.t()]
  def extraction_classes(%__MODULE__{extractions: extractions}) do
    extractions
    |> Enum.map(& &1.extraction_class)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns count of extractions.

  ## Examples

      iex> doc = %LeXtract.AnnotatedDocument{document_id: "doc-1", extractions: []}
      iex> LeXtract.AnnotatedDocument.count(doc)
      0

  """
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{extractions: extractions}), do: length(extractions)

  @doc """
  Returns true if document has any extractions.

  ## Examples

      iex> doc = %LeXtract.AnnotatedDocument{document_id: "doc-1", extractions: []}
      iex> LeXtract.AnnotatedDocument.has_extractions?(doc)
      false

  """
  @spec has_extractions?(t()) :: boolean()
  def has_extractions?(%__MODULE__{extractions: []}), do: false
  def has_extractions?(%__MODULE__{extractions: [_ | _]}), do: true
end
