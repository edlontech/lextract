defmodule LeXtract.CharInterval do
  @moduledoc """
  Represents a character position interval in text.

  ## Fields

  * `:start_pos` - Starting character position (0-based, inclusive)
  * `:end_pos` - Ending character position (0-based, exclusive)

  ## Examples

      iex> interval = %LeXtract.CharInterval{start_pos: 0, end_pos: 5}
      iex> LeXtract.CharInterval.length(interval)
      5

  """

  @type t :: %__MODULE__{
          start_pos: non_neg_integer(),
          end_pos: non_neg_integer()
        }

  @enforce_keys [:start_pos, :end_pos]
  defstruct [:start_pos, :end_pos]

  @doc """
  Creates a new character interval.

  ## Examples

      iex> LeXtract.CharInterval.new(0, 10)
      %LeXtract.CharInterval{start_pos: 0, end_pos: 10}

  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(start_pos, end_pos) when start_pos <= end_pos do
    %__MODULE__{start_pos: start_pos, end_pos: end_pos}
  end

  @doc """
  Returns the length of the interval.

  ## Examples

      iex> interval = LeXtract.CharInterval.new(10, 20)
      iex> LeXtract.CharInterval.length(interval)
      10

  """
  @spec length(t()) :: non_neg_integer()
  def length(%__MODULE__{start_pos: start_pos, end_pos: end_pos}) do
    end_pos - start_pos
  end

  @doc """
  Extracts text from a string using this interval.

  ## Examples

      iex> interval = LeXtract.CharInterval.new(0, 5)
      iex> LeXtract.CharInterval.extract("Hello, world!", interval)
      "Hello"

  """
  @spec extract(String.t(), t()) :: String.t()
  def extract(text, %__MODULE__{start_pos: start_pos, end_pos: end_pos}) do
    String.slice(text, start_pos, end_pos - start_pos)
  end

  @doc """
  Checks if two intervals overlap.

  ## Examples

      iex> i1 = LeXtract.CharInterval.new(0, 5)
      iex> i2 = LeXtract.CharInterval.new(3, 8)
      iex> LeXtract.CharInterval.overlaps?(i1, i2)
      true

      iex> i1 = LeXtract.CharInterval.new(0, 5)
      iex> i2 = LeXtract.CharInterval.new(5, 10)
      iex> LeXtract.CharInterval.overlaps?(i1, i2)
      false

  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(
        %__MODULE__{start_pos: s1, end_pos: e1},
        %__MODULE__{start_pos: s2, end_pos: e2}
      ) do
    s1 < e2 and s2 < e1
  end
end
