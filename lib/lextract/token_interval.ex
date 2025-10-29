defmodule LeXtract.TokenInterval do
  @moduledoc """
  Represents a token position interval.

  ## Fields

  * `:start_token` - Starting token index (0-based, inclusive)
  * `:end_token` - Ending token index (0-based, exclusive)

  ## Examples

      iex> interval = %LeXtract.TokenInterval{start_token: 0, end_token: 3}
      iex> LeXtract.TokenInterval.length(interval)
      3

  """

  @type t :: %__MODULE__{
          start_token: non_neg_integer(),
          end_token: non_neg_integer()
        }

  @enforce_keys [:start_token, :end_token]
  defstruct [:start_token, :end_token]

  @doc """
  Creates a new token interval.

  ## Examples

      iex> LeXtract.TokenInterval.new(0, 5)
      %LeXtract.TokenInterval{start_token: 0, end_token: 5}

  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(start_token, end_token) when start_token <= end_token do
    %__MODULE__{start_token: start_token, end_token: end_token}
  end

  @doc """
  Returns the number of tokens in the interval.

  ## Examples

      iex> interval = LeXtract.TokenInterval.new(5, 10)
      iex> LeXtract.TokenInterval.length(interval)
      5

  """
  @spec length(t()) :: non_neg_integer()
  def length(%__MODULE__{start_token: start_token, end_token: end_token}) do
    end_token - start_token
  end

  @doc """
  Checks if two token intervals overlap.

  ## Examples

      iex> i1 = LeXtract.TokenInterval.new(0, 5)
      iex> i2 = LeXtract.TokenInterval.new(3, 8)
      iex> LeXtract.TokenInterval.overlaps?(i1, i2)
      true

      iex> i1 = LeXtract.TokenInterval.new(0, 5)
      iex> i2 = LeXtract.TokenInterval.new(5, 10)
      iex> LeXtract.TokenInterval.overlaps?(i1, i2)
      false

  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(
        %__MODULE__{start_token: s1, end_token: e1},
        %__MODULE__{start_token: s2, end_token: e2}
      ) do
    s1 < e2 and s2 < e1
  end
end
