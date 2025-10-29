defmodule LeXtract.Extraction do
  @moduledoc """
  Represents a single extracted entity with alignment information.

  ## Fields

  * `:extraction_class` - Type/category of extraction (e.g., "person", "medication")
  * `:extraction_text` - The actual extracted text
  * `:char_interval` - Character position in source text
  * `:alignment_status` - Quality of text alignment (see `AlignmentStatus`)
  * `:extraction_index` - Position in extraction sequence (0-based)
  * `:group_index` - Grouping identifier for related extractions
  * `:description` - Optional description of the extraction
  * `:attributes` - Additional structured attributes (e.g., dosage, frequency)
  * `:token_interval` - Token position in source text

  ## Examples

      iex> extraction = %LeXtract.Extraction{
      ...>   extraction_class: "medication",
      ...>   extraction_text: "aspirin 81mg",
      ...>   char_interval: %LeXtract.CharInterval{start_pos: 0, end_pos: 12}
      ...> }
      iex> extraction.extraction_class
      "medication"

  """

  alias LeXtract.{AlignmentStatus, CharInterval, TokenInterval}

  @type t :: %__MODULE__{
          extraction_class: String.t(),
          extraction_text: String.t(),
          char_interval: CharInterval.t() | nil,
          alignment_status: AlignmentStatus.t() | nil,
          extraction_index: non_neg_integer() | nil,
          group_index: non_neg_integer() | nil,
          description: String.t() | nil,
          attributes: map() | nil,
          token_interval: TokenInterval.t() | nil
        }

  @enforce_keys [:extraction_class, :extraction_text]
  defstruct [
    :extraction_class,
    :extraction_text,
    :char_interval,
    :alignment_status,
    :extraction_index,
    :group_index,
    :description,
    :attributes,
    :token_interval
  ]

  @doc """
  Returns true if the extraction has alignment information.

  ## Examples

      iex> extraction = %LeXtract.Extraction{extraction_class: "person", extraction_text: "John Doe"}
      iex> LeXtract.Extraction.aligned?(extraction)
      false

  """
  @spec aligned?(t()) :: boolean()
  def aligned?(%__MODULE__{char_interval: nil}), do: false
  def aligned?(%__MODULE__{char_interval: %CharInterval{}}), do: true

  @doc """
  Returns true if the extraction has attributes.

  ## Examples

      iex> extraction = %LeXtract.Extraction{extraction_class: "person", extraction_text: "John Doe"}
      iex> LeXtract.Extraction.has_attributes?(extraction)
      false

  """
  @spec has_attributes?(t()) :: boolean()
  def has_attributes?(%__MODULE__{attributes: nil}), do: false
  def has_attributes?(%__MODULE__{attributes: attrs}) when map_size(attrs) == 0, do: false
  def has_attributes?(%__MODULE__{attributes: _attrs}), do: true
end
