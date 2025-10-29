defmodule LeXtract.Factory do
  @moduledoc """
  Factory functions for creating test data.
  """

  alias LeXtract.{
    AnnotatedDocument,
    CharInterval,
    Config,
    Document,
    Extraction,
    TextChunk,
    TokenInterval
  }

  @doc """
  Creates a sample extraction.
  """
  def build_extraction(attrs \\ []) do
    defaults = [
      extraction_class: "entity",
      extraction_text: "sample text",
      extraction_index: 0
    ]

    attrs = Keyword.merge(defaults, attrs)
    struct!(Extraction, attrs)
  end

  @doc """
  Creates a sample document.
  """
  def build_document(attrs \\ []) do
    defaults = [
      text: "This is a sample document for testing."
    ]

    attrs = Keyword.merge(defaults, attrs)
    Document.create(attrs[:text], Keyword.delete(attrs, :text))
  end

  @doc """
  Creates a sample annotated document.
  """
  def build_annotated_document(attrs \\ []) do
    defaults = [
      document_id: "test-doc-#{:rand.uniform(1000)}",
      extractions: [],
      text: "Sample text"
    ]

    attrs = Keyword.merge(defaults, attrs)

    %AnnotatedDocument{
      document_id: attrs[:document_id],
      extractions: attrs[:extractions],
      text: attrs[:text]
    }
  end

  @doc """
  Creates a sample text chunk.
  """
  def build_text_chunk(attrs \\ []) do
    defaults = [
      text: "This is a text chunk.",
      chunk_index: 0
    ]

    attrs = Keyword.merge(defaults, attrs)
    struct!(TextChunk, attrs)
  end

  @doc """
  Creates a sample character interval.
  """
  def build_char_interval(attrs \\ []) do
    defaults = [
      start_pos: 0,
      end_pos: 10
    ]

    attrs = Keyword.merge(defaults, attrs)
    struct!(CharInterval, attrs)
  end

  @doc """
  Creates a sample token interval.
  """
  def build_token_interval(attrs \\ []) do
    defaults = [
      start_token: 0,
      end_token: 5
    ]

    attrs = Keyword.merge(defaults, attrs)
    struct!(TokenInterval, attrs)
  end

  @doc """
  Creates a sample configuration.
  """
  def build_config(attrs \\ []) do
    Config.new(attrs)
  end
end
