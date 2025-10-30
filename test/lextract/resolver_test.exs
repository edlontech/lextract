defmodule LeXtract.ResolverTest do
  use ExUnit.Case, async: true
  doctest LeXtract.Resolver

  alias LeXtract.Resolver

  describe "resolve/2 with JSON" do
    test "parses simple extraction array" do
      json = """
      [
        {"person": "John Doe", "person_index": 0},
        {"person": "Jane Smith", "person_index": 1}
      ]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert length(extractions) == 2
      assert Enum.at(extractions, 0).extraction_class == "person"
      assert Enum.at(extractions, 0).extraction_text == "John Doe"
      assert Enum.at(extractions, 0).extraction_index == 0
      assert Enum.at(extractions, 1).extraction_text == "Jane Smith"
      assert Enum.at(extractions, 1).extraction_index == 1
    end

    test "extracts attributes" do
      json = """
      [{
        "medication": "aspirin",
        "medication_index": 0,
        "medication_attributes": {"dosage": "81mg", "frequency": "daily"}
      }]
      """

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_class == "medication"
      assert extraction.extraction_text == "aspirin"
      assert extraction.extraction_index == 0
      assert extraction.attributes["dosage"] == "81mg"
      assert extraction.attributes["frequency"] == "daily"
    end

    test "handles fenced JSON" do
      json = """
      ```json
      [{"person": "John", "person_index": 0}]
      ```
      """

      {:ok, extractions} = Resolver.resolve(json, :json)
      assert length(extractions) == 1
      assert hd(extractions).extraction_text == "John"
    end

    test "handles extractions key with string" do
      json = """
      {
        "extractions": [
          {"person": "John", "person_index": 0}
        ]
      }
      """

      {:ok, extractions} = Resolver.resolve(json, :json)
      assert length(extractions) == 1
      assert hd(extractions).extraction_class == "person"
    end

    test "returns error for malformed JSON" do
      json = "{invalid json}"

      {:error, %LeXtract.Error.Processing.Parsing{}} = Resolver.resolve(json, :json)
    end

    test "handles multiple extraction classes per item" do
      json = """
      [{
        "person": "John",
        "organization": "Acme Corp",
        "person_index": 0,
        "organization_index": 1
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert length(extractions) == 2

      person = Enum.find(extractions, &(&1.extraction_class == "person"))
      org = Enum.find(extractions, &(&1.extraction_class == "organization"))

      assert person.extraction_text == "John"
      assert person.extraction_index == 0
      assert org.extraction_text == "Acme Corp"
      assert org.extraction_index == 1
    end

    test "uses default index when not specified" do
      json = """
      [
        {"entity": "first"},
        {"entity": "second"}
      ]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert Enum.at(extractions, 0).extraction_index == 0
      assert Enum.at(extractions, 1).extraction_index == 1
    end

    test "handles empty extraction array" do
      json = "[]"

      {:ok, extractions} = Resolver.resolve(json, :json)
      assert extractions == []
    end

    test "handles extraction without attributes" do
      json = ~s([{"person": "John"}])

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_class == "person"
      assert extraction.extraction_text == "John"
      assert is_nil(extraction.attributes)
    end

    test "sorts extractions by index" do
      json = """
      [
        {"entity": "third", "entity_index": 2},
        {"entity": "first", "entity_index": 0},
        {"entity": "second", "entity_index": 1}
      ]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert Enum.at(extractions, 0).extraction_text == "first"
      assert Enum.at(extractions, 1).extraction_text == "second"
      assert Enum.at(extractions, 2).extraction_text == "third"
    end
  end

  describe "resolve/2 with YAML" do
    test "parses simple YAML extraction" do
      yaml = """
      - person: John Doe
        person_index: 0
      - person: Jane Smith
        person_index: 1
      """

      {:ok, extractions} = Resolver.resolve(yaml, :yaml)

      assert length(extractions) == 2
      assert Enum.at(extractions, 0).extraction_text == "John Doe"
      assert Enum.at(extractions, 1).extraction_text == "Jane Smith"
    end

    test "handles fenced YAML" do
      yaml = """
      ```yaml
      - person: John
        person_index: 0
      ```
      """

      {:ok, extractions} = Resolver.resolve(yaml, :yaml)
      assert length(extractions) == 1
      assert hd(extractions).extraction_text == "John"
    end

    test "extracts YAML attributes" do
      yaml = """
      - medication: aspirin
        medication_index: 0
        medication_attributes:
          dosage: 81mg
          frequency: daily
      """

      {:ok, [extraction]} = Resolver.resolve(yaml, :yaml)

      assert extraction.extraction_class == "medication"
      assert extraction.attributes["dosage"] == "81mg"
      assert extraction.attributes["frequency"] == "daily"
    end

    test "handles YAML with extractions key" do
      yaml = """
      extractions:
        - entity: test
          entity_index: 0
      """

      {:ok, extractions} = Resolver.resolve(yaml, :yaml)
      assert length(extractions) == 1
      assert hd(extractions).extraction_class == "entity"
    end

    test "returns error for invalid YAML" do
      yaml = ":\n  invalid: yaml: structure"

      {:error, %LeXtract.Error.Processing.Parsing{}} = Resolver.resolve(yaml, :yaml)
    end
  end

  describe "resolve_parsed/1" do
    test "resolves from already-parsed list" do
      data = [
        %{"person" => "John", "person_index" => 0},
        %{"person" => "Jane", "person_index" => 1}
      ]

      {:ok, extractions} = Resolver.resolve_parsed(data)

      assert length(extractions) == 2
      assert Enum.at(extractions, 0).extraction_text == "John"
      assert Enum.at(extractions, 1).extraction_text == "Jane"
    end

    test "resolves from map with string extractions key" do
      data = %{"extractions" => [%{"entity" => "test", "entity_index" => 0}]}

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert extraction.extraction_class == "entity"
      assert extraction.extraction_text == "test"
    end

    test "resolves from map with atom extractions key" do
      data = %{extractions: [%{"entity" => "test", "entity_index" => 0}]}

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert extraction.extraction_class == "entity"
      assert extraction.extraction_text == "test"
    end

    test "returns error for invalid structure" do
      data = %{"invalid" => "structure"}

      {:error, %LeXtract.Error.Processing.Resolution{}} = Resolver.resolve_parsed(data)
    end

    test "handles parsed data with attributes" do
      data = [
        %{
          "medication" => "aspirin",
          "medication_attributes" => %{"dosage" => "81mg"}
        }
      ]

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert extraction.attributes["dosage"] == "81mg"
    end
  end

  describe "attribute extraction" do
    test "extracts simple attributes" do
      json = """
      [{
        "drug": "ibuprofen",
        "drug_attributes": {"strength": "200mg"}
      }]
      """

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.attributes["strength"] == "200mg"
    end

    test "extracts multiple attributes" do
      json = """
      [{
        "medication": "aspirin",
        "medication_attributes": {
          "dosage": "81mg",
          "frequency": "daily",
          "route": "oral"
        }
      }]
      """

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.attributes["dosage"] == "81mg"
      assert extraction.attributes["frequency"] == "daily"
      assert extraction.attributes["route"] == "oral"
    end

    test "handles nested attribute values" do
      json = """
      [{
        "entity": "test",
        "entity_attributes": {
          "metadata": {
            "key": "value"
          }
        }
      }]
      """

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert is_map(extraction.attributes["metadata"])
      assert extraction.attributes["metadata"]["key"] == "value"
    end

    test "normalizes atom keys in attributes to strings" do
      data = [
        %{
          "entity" => "test",
          "entity_attributes" => %{:key => "value", "other" => "data"}
        }
      ]

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert extraction.attributes["key"] == "value"
      assert extraction.attributes["other"] == "data"
    end

    test "handles atom attribute keys in parsed data" do
      data = [
        %{
          "medication" => "aspirin",
          :medication_attributes => %{"dosage" => "81mg"}
        }
      ]

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert extraction.attributes["dosage"] == "81mg"
    end

    test "handles atom index keys in parsed data" do
      data = [
        %{
          "entity" => "test",
          :entity_index => 5
        }
      ]

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert extraction.extraction_index == 5
    end

    test "ignores non-map attribute values" do
      data = [
        %{
          "entity" => "test",
          "entity_attributes" => "invalid"
        }
      ]

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert is_nil(extraction.attributes)
    end
  end

  describe "index extraction" do
    test "extracts explicit index" do
      json = ~s([{"entity": "test", "entity_index": 5}])

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_index == 5
    end

    test "uses default index from array position" do
      json = """
      [
        {"entity": "first"},
        {"entity": "second"},
        {"entity": "third"}
      ]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert Enum.at(extractions, 0).extraction_index == 0
      assert Enum.at(extractions, 1).extraction_index == 1
      assert Enum.at(extractions, 2).extraction_index == 2
    end

    test "handles string index values" do
      json = ~s([{"entity": "test", "entity_index": "42"}])

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_index == 42
    end

    test "ignores invalid index types" do
      json = ~s([{"entity": "test", "entity_index": 3.14}])

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_index == 0
    end

    test "prefers explicit index over default" do
      json = """
      [
        {"entity": "test", "entity_index": 99}
      ]
      """

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_index == 99
    end
  end

  describe "multiple extraction classes" do
    test "extracts multiple classes from single item" do
      json = """
      [{
        "person": "John Doe",
        "organization": "Acme Corp",
        "location": "New York"
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert length(extractions) == 3

      classes = Enum.map(extractions, & &1.extraction_class) |> Enum.sort()
      assert classes == ["location", "organization", "person"]
    end

    test "handles different indices for different classes" do
      json = """
      [{
        "person": "John",
        "person_index": 10,
        "organization": "Acme",
        "organization_index": 20
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      person = Enum.find(extractions, &(&1.extraction_class == "person"))
      org = Enum.find(extractions, &(&1.extraction_class == "organization"))

      assert person.extraction_index == 10
      assert org.extraction_index == 20
    end

    test "handles attributes for multiple classes" do
      json = """
      [{
        "person": "John",
        "person_attributes": {"age": "30"},
        "organization": "Acme",
        "organization_attributes": {"type": "corporation"}
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      person = Enum.find(extractions, &(&1.extraction_class == "person"))
      org = Enum.find(extractions, &(&1.extraction_class == "organization"))

      assert person.attributes["age"] == "30"
      assert org.attributes["type"] == "corporation"
    end
  end

  describe "list values" do
    test "handles extraction class with list of values" do
      json = """
      [{
        "medication": ["aspirin", "ibuprofen", "acetaminophen"]
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert length(extractions) == 3
      texts = Enum.map(extractions, & &1.extraction_text)
      assert texts == ["aspirin", "ibuprofen", "acetaminophen"]
    end

    test "assigns sequential indices to list values" do
      json = """
      [{
        "entity": ["first", "second", "third"]
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert Enum.at(extractions, 0).extraction_index == 0
      assert Enum.at(extractions, 1).extraction_index == 1
      assert Enum.at(extractions, 2).extraction_index == 2
    end

    test "shares attributes across list values" do
      json = """
      [{
        "drug": ["aspirin", "ibuprofen"],
        "drug_attributes": {"category": "NSAID"}
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert length(extractions) == 2
      assert Enum.at(extractions, 0).attributes["category"] == "NSAID"
      assert Enum.at(extractions, 1).attributes["category"] == "NSAID"
    end
  end

  describe "edge cases" do
    test "handles empty extractions array" do
      json = ~s({"extractions": []})

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert extractions == []
    end

    test "handles item with non-string values" do
      json = """
      [{
        "numeric_field": 123,
        "boolean_field": true,
        "null_field": null
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert extractions == []
    end

    test "handles item with only metadata fields" do
      json = """
      [{
        "entity_index": 0,
        "entity_attributes": {"key": "value"}
      }]
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert extractions == []
    end

    test "handles unicode text" do
      json = ~s([{"person": "José García", "person_index": 0}])

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_text == "José García"
    end

    test "handles emoji in text" do
      json = ~s([{"message": "Hello 👋", "message_index": 0}])

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_text == "Hello 👋"
    end

    test "handles extraction with empty string value" do
      json = ~s([{"entity": "", "entity_index": 0}])

      {:ok, [extraction]} = Resolver.resolve(json, :json)

      assert extraction.extraction_text == ""
    end

    test "handles mixed string and atom keys in parsed data" do
      data = [
        %{
          "person" => "John",
          :person_index => 0,
          "person_attributes" => %{age: "30"}
        }
      ]

      {:ok, [extraction]} = Resolver.resolve_parsed(data)

      assert extraction.extraction_text == "John"
      assert extraction.extraction_index == 0
      assert extraction.attributes["age"] == "30"
    end
  end

  describe "integration" do
    test "full workflow with realistic JSON" do
      json = """
      {
        "extractions": [
          {
            "medication": "aspirin",
            "medication_index": 0,
            "medication_attributes": {
              "dosage": "81mg",
              "frequency": "daily",
              "route": "oral"
            }
          },
          {
            "medication": "metformin",
            "medication_index": 1,
            "medication_attributes": {
              "dosage": "500mg",
              "frequency": "twice daily"
            }
          }
        ]
      }
      """

      {:ok, extractions} = Resolver.resolve(json, :json)

      assert length(extractions) == 2

      aspirin = Enum.at(extractions, 0)
      assert aspirin.extraction_class == "medication"
      assert aspirin.extraction_text == "aspirin"
      assert aspirin.extraction_index == 0
      assert aspirin.attributes["dosage"] == "81mg"
      assert aspirin.attributes["frequency"] == "daily"

      metformin = Enum.at(extractions, 1)
      assert metformin.extraction_text == "metformin"
      assert metformin.extraction_index == 1
    end

    test "full workflow with fenced YAML" do
      yaml = """
      ```yaml
      extractions:
        - person: John Doe
          person_index: 0
          person_attributes:
            age: "30"
            occupation: "engineer"
        - organization: Acme Corp
          organization_index: 1
          organization_attributes:
            industry: "technology"
      ```
      """

      {:ok, extractions} = Resolver.resolve(yaml, :yaml)

      assert length(extractions) == 2

      person = Enum.find(extractions, &(&1.extraction_class == "person"))
      org = Enum.find(extractions, &(&1.extraction_class == "organization"))

      assert person.extraction_text == "John Doe"
      assert person.attributes["age"] == "30"
      assert org.extraction_text == "Acme Corp"
      assert org.attributes["industry"] == "technology"
    end
  end
end
