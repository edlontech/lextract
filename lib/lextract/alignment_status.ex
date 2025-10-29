defmodule LeXtract.AlignmentStatus do
  @moduledoc """
  Represents the quality/status of text alignment.

  ## Values

  * `:exact` - Perfect token sequence match
  * `:fuzzy` - Case-insensitive or minor variation match
  * `:partial` - Partial/substring match
  * `:none` - No match found

  ## Examples

      iex> LeXtract.AlignmentStatus.exact?(:exact)
      true

      iex> LeXtract.AlignmentStatus.exact?(:fuzzy)
      false

  """

  @type t :: :exact | :fuzzy | :partial | :none

  @doc """
  Returns true if status indicates exact match.

  ## Examples

      iex> LeXtract.AlignmentStatus.exact?(:exact)
      true

      iex> LeXtract.AlignmentStatus.exact?(:partial)
      false

  """
  @spec exact?(t()) :: boolean()
  def exact?(:exact), do: true
  def exact?(_), do: false

  @doc """
  Returns true if status indicates any match (not :none).

  ## Examples

      iex> LeXtract.AlignmentStatus.matched?(:exact)
      true

      iex> LeXtract.AlignmentStatus.matched?(:none)
      false

  """
  @spec matched?(t()) :: boolean()
  def matched?(:none), do: false
  def matched?(_), do: true

  @doc """
  Returns confidence score for alignment status (0.0 - 1.0).

  ## Examples

      iex> LeXtract.AlignmentStatus.confidence(:exact)
      1.0

      iex> LeXtract.AlignmentStatus.confidence(:none)
      0.0

  """
  @spec confidence(t()) :: float()
  def confidence(:exact), do: 1.0
  def confidence(:fuzzy), do: 0.8
  def confidence(:partial), do: 0.5
  def confidence(:none), do: 0.0

  @doc """
  Converts string to alignment status atom.

  ## Examples

      iex> LeXtract.AlignmentStatus.from_string("exact")
      :exact

      iex> LeXtract.AlignmentStatus.from_string("unknown")
      :none

  """
  @spec from_string(String.t()) :: t()
  def from_string("exact"), do: :exact
  def from_string("fuzzy"), do: :fuzzy
  def from_string("partial"), do: :partial
  def from_string("none"), do: :none
  def from_string(_), do: :none
end
