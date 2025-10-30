defmodule LeXtract.Schema.Analyzer do
  @moduledoc """
  Analyzes example extractions to infer schema information.

  Examines extraction examples to identify:
  - Extraction classes (e.g., "Medication", "Person")
  - Attribute names (e.g., medication_attributes, person_attributes)
  - Attribute types (string, list, map, etc.)
  - Nested structures

  ## Example

      iex> examples = [
      ...>   %LeXtract.ExampleData{
      ...>     input: "Patient takes aspirin 100mg daily",
      ...>     output: %{
      ...>       "extractions" => [
      ...>         %{
      ...>           "class" => "Medication",
      ...>           "medication_attributes" => %{
      ...>             "name" => "aspirin",
      ...>             "dosage" => "100mg"
      ...>           }
      ...>         }
      ...>       ]
      ...>     }
      ...>   }
      ...> ]
      iex> schema_info = LeXtract.Schema.Analyzer.analyze(examples)
      iex> schema_info.classes
      ["Medication"]
      iex> Map.has_key?(schema_info.attributes, "Medication")
      true

  """

  alias LeXtract.ExampleData

  @type schema_info :: %{
          classes: [String.t()],
          attributes: %{String.t() => [String.t()]},
          types: %{String.t() => atom()}
        }

  @doc """
  Analyzes examples to extract schema information.

  Returns a map with:
  - :classes - List of extraction class names
  - :attributes - Map of class -> attribute names
  - :types - Map of attribute path -> inferred type

  ## Examples

      iex> examples = [
      ...>   %LeXtract.ExampleData{
      ...>     input: "Dr. Smith treated John",
      ...>     output: %{
      ...>       "extractions" => [
      ...>         %{
      ...>           "class" => "Person",
      ...>           "person_attributes" => %{"name" => "Dr. Smith"}
      ...>         },
      ...>         %{
      ...>           "class" => "Person",
      ...>           "person_attributes" => %{"name" => "John"}
      ...>         }
      ...>       ]
      ...>     }
      ...>   }
      ...> ]
      iex> result = LeXtract.Schema.Analyzer.analyze(examples)
      iex> result.classes
      ["Person"]

  """
  @spec analyze([ExampleData.t()]) :: schema_info()
  def analyze(examples) when is_list(examples) do
    classes = extract_classes(examples)
    attributes = extract_attributes(examples, classes)
    types = infer_types(examples, attributes)

    %{
      classes: classes,
      attributes: attributes,
      types: types
    }
  end

  @doc """
  Converts analyzed schema to NimbleOptions format.

  Returns a keyword list suitable for ReqLLM's generate_object/4.
  Note: Due to NimbleOptions limitations with nested validation in lists,
  the schema provides basic validation for the extractions list structure
  but does not deeply validate nested attribute maps.

  ## Examples

      iex> schema_info = %{
      ...>   classes: ["Medication"],
      ...>   attributes: %{"Medication" => ["name", "dosage"]},
      ...>   types: %{
      ...>     "Medication.name" => :string,
      ...>     "Medication.dosage" => :string
      ...>   }
      ...> }
      iex> schema = LeXtract.Schema.Analyzer.to_nimble_options(schema_info)
      iex> Keyword.has_key?(schema, :extractions)
      true

  """
  @spec to_nimble_options(schema_info()) :: keyword()
  def to_nimble_options(%{classes: _classes, attributes: _attributes, types: _types}) do
    # NOTE: We generate a generic schema because NimbleOptions does not currently
    # support validating the keys of maps inside a list in a way that allows for
    # dynamic, multi-class structures like ours (e.g., one item could be a
    # "Person" map, the next a "Medication" map with different keys).
    # The type analysis is kept for potential future enhancements.
    [
      extractions: [
        type: {:list, :map},
        default: [],
        doc: "List of extracted entities"
      ]
    ]
  end

  defp extract_classes(examples) do
    examples
    |> Enum.flat_map(fn %ExampleData{output: output} ->
      get_extractions(output)
      |> Enum.map(fn extraction ->
        get_class(extraction)
      end)
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp extract_attributes(examples, classes) do
    Enum.reduce(classes, %{}, fn class, acc ->
      attrs = find_attributes_for_class(examples, class)
      Map.put(acc, class, attrs)
    end)
  end

  defp find_attributes_for_class(examples, class) do
    attribute_key = class_to_attribute_key(class)

    examples
    |> Enum.flat_map(&extract_class_attributes(&1, class, attribute_key))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp extract_class_attributes(%ExampleData{output: output}, class, attribute_key) do
    output
    |> get_extractions()
    |> Enum.filter(fn extraction -> get_class(extraction) == class end)
    |> Enum.flat_map(fn extraction ->
      case get_attributes(extraction, attribute_key) do
        nil -> []
        attrs when is_map(attrs) -> Map.keys(attrs)
        _ -> []
      end
    end)
  end

  defp infer_types(examples, attributes) do
    Enum.reduce(attributes, %{}, fn {class, attr_list}, acc ->
      attribute_key = class_to_attribute_key(class)

      Enum.reduce(attr_list, acc, fn attr_name, inner_acc ->
        path = "#{class}.#{attr_name}"
        type = infer_type_for_attribute(examples, class, attribute_key, attr_name)
        Map.put(inner_acc, path, type)
      end)
    end)
  end

  defp infer_type_for_attribute(examples, class, attribute_key, attr_name) do
    sample_values =
      examples
      |> Enum.flat_map(&collect_attribute_values(&1, class, attribute_key, attr_name))

    case sample_values do
      [] -> :string
      [first | _] -> infer_type_from_value(first)
    end
  end

  defp collect_attribute_values(%ExampleData{output: output}, class, attribute_key, attr_name) do
    output
    |> get_extractions()
    |> Enum.filter(fn extraction -> get_class(extraction) == class end)
    |> Enum.map(fn extraction ->
      case get_attributes(extraction, attribute_key) do
        attrs when is_map(attrs) -> Map.get(attrs, attr_name)
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp infer_type_from_value(value) when is_binary(value), do: :string
  defp infer_type_from_value(value) when is_integer(value), do: :integer
  defp infer_type_from_value(value) when is_float(value), do: :float
  defp infer_type_from_value(value) when is_boolean(value), do: :boolean

  defp infer_type_from_value(value) when is_list(value),
    do: {:list, infer_list_element_type(value)}

  defp infer_type_from_value(value) when is_map(value), do: :map
  defp infer_type_from_value(_), do: :string

  defp infer_list_element_type([]), do: :string
  defp infer_list_element_type([first | _]), do: infer_type_from_value(first)

  defp get_extractions(output) when is_map(output) do
    Map.get(output, "extractions", []) || []
  end

  defp get_extractions(_), do: []

  defp get_class(extraction) when is_map(extraction) do
    Map.get(extraction, "class") || Map.get(extraction, :class)
  end

  defp get_class(_), do: nil

  defp get_attributes(extraction, attribute_key) when is_map(extraction) do
    Map.get(extraction, attribute_key) || Map.get(extraction, String.to_atom(attribute_key))
  end

  defp get_attributes(_, _), do: nil

  defp class_to_attribute_key(class) when is_binary(class) and class != "" do
    class
    |> Macro.underscore()
    |> Kernel.<>("_attributes")
  end
end
