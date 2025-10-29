defmodule LeXtract.Resolver do
  @moduledoc """
  Parses LLM output into Extraction structs.

  Handles conversion from JSON/YAML format to structured Extraction records,
  including attribute extraction and index parsing.

  ## Supported Formats

  ### List of extractions directly:
  ```json
  [
    {
      "entity": "aspirin",
      "entity_index": 0,
      "entity_attributes": {"dosage": "81mg"}
    }
  ]
  ```

  ### Extractions key:
  ```yaml
  extractions:
    - medication: "aspirin"
      medication_index: 0
      medication_attributes:
        dosage: "81mg"
        frequency: "daily"
  ```

  ### Multiple extraction classes per item:
  ```json
  [
    {
      "person": "John Doe",
      "organization": "Acme Corp",
      "person_index": 0,
      "organization_index": 1
    }
  ]
  ```

  ## Examples

      iex> json = ~s([{"person": "John Doe", "person_index": 0}])
      iex> {:ok, [extraction]} = LeXtract.Resolver.resolve(json, :json)
      iex> extraction.extraction_class
      "person"
      iex> extraction.extraction_text
      "John Doe"
      iex> extraction.extraction_index
      0

  """

  alias LeXtract.{Extraction, FormatHandler}

  @type resolve_result :: {:ok, [Extraction.t()]} | {:error, String.t()}

  @doc """
  Resolves LLM text output into a list of Extraction structs.

  Automatically parses the text in the specified format and converts
  the structured data into Extraction records.

  ## Examples

      iex> json = ~s([{"person": "John Doe", "person_index": 0}])
      iex> {:ok, extractions} = LeXtract.Resolver.resolve(json, :json)
      iex> length(extractions)
      1

      iex> yaml = "- medication: aspirin\\n  medication_index: 0"
      iex> {:ok, extractions} = LeXtract.Resolver.resolve(yaml, :yaml)
      iex> hd(extractions).extraction_class
      "medication"

  """
  @spec resolve(String.t(), FormatHandler.format()) :: resolve_result()
  def resolve(text, format) do
    with {:ok, parsed} <- FormatHandler.parse(text, format),
         {:ok, extraction_data} <- extract_extractions_data(parsed),
         extractions <- convert_to_extractions(extraction_data) do
      {:ok, extractions}
    end
  end

  @doc """
  Resolves from already-parsed data (map or list).

  Useful when data has been parsed elsewhere.

  ## Examples

      iex> data = [%{"person" => "Jane", "person_index" => 1}]
      iex> {:ok, [extraction]} = LeXtract.Resolver.resolve_parsed(data)
      iex> extraction.extraction_text
      "Jane"

      iex> data = %{"extractions" => [%{"entity" => "test"}]}
      iex> {:ok, [extraction]} = LeXtract.Resolver.resolve_parsed(data)
      iex> extraction.extraction_class
      "entity"

  """
  @spec resolve_parsed(term()) :: resolve_result()
  def resolve_parsed(parsed_data) do
    with {:ok, extraction_data} <- extract_extractions_data(parsed_data),
         extractions <- convert_to_extractions(extraction_data) do
      {:ok, extractions}
    end
  end

  defp extract_extractions_data(data) when is_list(data) do
    {:ok, data}
  end

  defp extract_extractions_data(%{"extractions" => extractions}) when is_list(extractions) do
    {:ok, extractions}
  end

  defp extract_extractions_data(%{extractions: extractions}) when is_list(extractions) do
    {:ok, extractions}
  end

  defp extract_extractions_data(_) do
    {:error, "Could not find extractions array in parsed data"}
  end

  defp convert_to_extractions(extraction_data) do
    extraction_data
    |> Enum.with_index()
    |> Enum.flat_map(fn {item, default_index} ->
      extract_from_item(item, default_index)
    end)
    |> Enum.sort_by(& &1.extraction_index)
  end

  defp extract_from_item(item, default_index) when is_map(item) do
    item
    |> Enum.flat_map(fn {key, value} ->
      process_item_field(item, normalize_key(key), value, default_index)
    end)
  end

  defp extract_from_item(_, _), do: []

  defp process_item_field(item, key_string, value, default_index) when is_binary(value) do
    if metadata_field?(key_string) do
      []
    else
      build_extraction_from_string(item, key_string, value, default_index)
    end
  end

  defp process_item_field(item, key_string, value, _default_index) when is_list(value) do
    if metadata_field?(key_string) do
      []
    else
      build_extractions_from_list(item, key_string, value)
    end
  end

  defp process_item_field(_item, _key_string, _value, _default_index), do: []

  defp metadata_field?(key_string) do
    String.ends_with?(key_string, "_attributes") or String.ends_with?(key_string, "_index")
  end

  defp build_extraction_from_string(item, extraction_class, value, default_index) do
    attributes = get_attributes(item, extraction_class)
    index = get_index(item, extraction_class) || default_index

    [
      %Extraction{
        extraction_class: extraction_class,
        extraction_text: value,
        attributes: attributes,
        extraction_index: index
      }
    ]
  end

  defp build_extractions_from_list(item, extraction_class, value) do
    attributes = get_attributes(item, extraction_class)

    Enum.map(Enum.with_index(value), fn {text, idx} ->
      %Extraction{
        extraction_class: extraction_class,
        extraction_text: text,
        attributes: attributes,
        extraction_index: idx
      }
    end)
  end

  defp get_attributes(item, extraction_class) do
    attribute_key_variations = [
      "#{extraction_class}_attributes",
      String.to_atom("#{extraction_class}_attributes")
    ]

    attribute_key_variations
    |> Enum.find_value(fn key ->
      case Map.get(item, key) do
        nil -> nil
        attrs when is_map(attrs) -> normalize_map_keys(attrs)
        _ -> nil
      end
    end)
  end

  defp get_index(item, extraction_class) do
    index_key_variations = [
      "#{extraction_class}_index",
      String.to_atom("#{extraction_class}_index")
    ]

    index_key_variations
    |> Enum.find_value(fn key ->
      item
      |> Map.get(key)
      |> normalize_index()
    end)
  end

  defp normalize_index(nil), do: nil
  defp normalize_index(idx) when is_integer(idx), do: idx
  defp normalize_index(idx) when is_binary(idx), do: String.to_integer(idx)
  defp normalize_index(_), do: nil

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key

  defp normalize_map_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {normalize_key(k), v}
    end)
  end
end
