defmodule LeXtract.FormatType do
  @moduledoc """
  Enumeration of supported format types for parsing LLM outputs.

  Supports JSON and YAML formats for structured data extraction.

  ## Examples

      iex> LeXtract.FormatType.from_string("json")
      {:ok, :json}

      iex> LeXtract.FormatType.to_string(:yaml)
      "yaml"

      iex> LeXtract.FormatType.all()
      [:json, :yaml]

  """

  @type t :: :json | :yaml

  @doc """
  Converts a string to a format type atom.

  Accepts "json", "yaml", and "yml" as valid format strings.

  ## Examples

      iex> LeXtract.FormatType.from_string("json")
      {:ok, :json}

      iex> LeXtract.FormatType.from_string("yaml")
      {:ok, :yaml}

      iex> LeXtract.FormatType.from_string("yml")
      {:ok, :yaml}

      iex> LeXtract.FormatType.from_string("invalid")
      {:error, "Unknown format type: invalid"}

  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_string("json"), do: {:ok, :json}
  def from_string("yaml"), do: {:ok, :yaml}
  def from_string("yml"), do: {:ok, :yaml}
  def from_string(other), do: {:error, "Unknown format type: #{other}"}

  @doc """
  Converts a format type atom to its string representation.

  ## Examples

      iex> LeXtract.FormatType.to_string(:json)
      "json"

      iex> LeXtract.FormatType.to_string(:yaml)
      "yaml"

  """
  @spec to_string(t()) :: String.t()
  def to_string(:json), do: "json"
  def to_string(:yaml), do: "yaml"

  @doc """
  Returns a list of all supported format types.

  ## Examples

      iex> LeXtract.FormatType.all()
      [:json, :yaml]

  """
  @spec all() :: [t()]
  def all, do: [:json, :yaml]
end
