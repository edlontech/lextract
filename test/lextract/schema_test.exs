defmodule LeXtract.SchemaTest do
  use ExUnit.Case, async: true

  alias LeXtract.ExampleData
  alias LeXtract.Schema

  doctest LeXtract.Schema

  describe "from_examples/2" do
    test "generates schema from single medication example" do
      examples = [
        %ExampleData{
          input: "Patient takes aspirin 100mg",
          output: %{
            "extractions" => [
              %{
                "class" => "Medication",
                "medication_attributes" => %{"name" => "aspirin", "dosage" => "100mg"}
              }
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:type] == {:list, :map}
      assert schema[:extractions][:default] == []
    end

    test "generates schema from multiple extraction classes" do
      examples = [
        %ExampleData{
          input: "Dr. Smith prescribed aspirin to patient",
          output: %{
            "extractions" => [
              %{
                "class" => "Person",
                "person_attributes" => %{"name" => "Dr. Smith"}
              },
              %{
                "class" => "Medication",
                "medication_attributes" => %{"name" => "aspirin"}
              }
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      assert schema[:extractions][:type] == {:list, :map}
    end

    test "generates schema with various attribute types" do
      examples = [
        %ExampleData{
          input: "Test with various types",
          output: %{
            "extractions" => [
              %{
                "class" => "Data",
                "data_attributes" => %{
                  "count" => 42,
                  "ratio" => 3.14,
                  "active" => true,
                  "tags" => ["a", "b"]
                }
              }
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      assert schema[:extractions][:type] == {:list, :map}
    end

    test "handles empty examples list" do
      schema = Schema.from_examples([])

      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:default] == []
    end

    test "merges with manual schema when provided" do
      examples = [
        %ExampleData{
          input: "Test",
          output: %{
            "extractions" => [
              %{"class" => "Entity", "entity_attributes" => %{"name" => "test"}}
            ]
          }
        }
      ]

      manual_schema = [
        extractions: [
          type: {:list, [type: :map]},
          required: true,
          doc: "Custom documentation"
        ]
      ]

      schema = Schema.from_examples(examples, manual_schema: manual_schema)

      assert schema[:extractions][:required] == true
      assert schema[:extractions][:doc] == "Custom documentation"
    end

    test "applies custom options" do
      examples = [
        %ExampleData{
          input: "Test",
          output: %{
            "extractions" => [%{"class" => "Test", "test_attributes" => %{"field" => "value"}}]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      assert is_list(schema)
    end
  end

  describe "validate/2" do
    test "validates correct data against schema" do
      schema = [
        extractions: [
          type: {:list, :map},
          default: []
        ]
      ]

      data = [extractions: []]

      assert {:ok, validated} = Schema.validate(data, schema)
      assert validated[:extractions] == []
    end

    test "validates data with extractions" do
      schema = [
        extractions: [
          type: {:list, :map},
          default: []
        ]
      ]

      data = [extractions: [%{class: "Test"}]]

      assert {:ok, validated} = Schema.validate(data, schema)
      assert length(validated[:extractions]) == 1
    end

    test "returns error for invalid data" do
      schema = [
        extractions: [
          type: {:list, :map},
          required: true
        ]
      ]

      data = []

      assert {:error, %NimbleOptions.ValidationError{}} = Schema.validate(data, schema)
    end

    test "returns error for wrong type" do
      schema = [
        extractions: [
          type: {:list, :map},
          default: []
        ]
      ]

      data = [extractions: "not a list"]

      assert {:error, %NimbleOptions.ValidationError{}} = Schema.validate(data, schema)
    end

    test "validates against generated schema" do
      examples = [
        %ExampleData{
          input: "Test",
          output: %{
            "extractions" => [
              %{"class" => "Entity", "entity_attributes" => %{"name" => "test"}}
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)
      data = [extractions: []]

      assert {:ok, _validated} = Schema.validate(data, schema)
    end
  end

  describe "merge/2" do
    test "merges simple schemas" do
      generated = [
        name: [type: :string],
        age: [type: :integer]
      ]

      user = [
        age: [type: :integer, required: true]
      ]

      merged = Schema.merge(generated, user)

      assert Keyword.has_key?(merged, :name)
      assert Keyword.has_key?(merged, :age)
      assert merged[:age][:required] == true
      assert merged[:age][:type] == :integer
    end

    test "user schema takes precedence" do
      generated = [
        field: [type: :string, default: "gen"]
      ]

      user = [
        field: [type: :string, default: "user"]
      ]

      merged = Schema.merge(generated, user)

      assert merged[:field][:default] == "user"
    end

    test "preserves generated fields not in user schema" do
      generated = [
        field_a: [type: :string],
        field_b: [type: :integer],
        field_c: [type: :boolean]
      ]

      user = [
        field_b: [type: :integer, required: true]
      ]

      merged = Schema.merge(generated, user)

      assert Keyword.has_key?(merged, :field_a)
      assert Keyword.has_key?(merged, :field_b)
      assert Keyword.has_key?(merged, :field_c)
      assert merged[:field_b][:required] == true
    end

    test "adds new fields from user schema" do
      generated = [
        field_a: [type: :string]
      ]

      user = [
        field_b: [type: :integer],
        field_c: [type: :boolean]
      ]

      merged = Schema.merge(generated, user)

      assert Keyword.has_key?(merged, :field_a)
      assert Keyword.has_key?(merged, :field_b)
      assert Keyword.has_key?(merged, :field_c)
    end

    test "merges nested keys in map types" do
      generated = [
        data: [
          type: :map,
          keys: [
            field_a: [type: :string],
            field_b: [type: :integer]
          ]
        ]
      ]

      user = [
        data: [
          type: :map,
          keys: [
            field_b: [type: :integer, required: true],
            field_c: [type: :boolean]
          ]
        ]
      ]

      merged = Schema.merge(generated, user)

      data_opts = merged[:data]
      keys = data_opts[:keys]

      assert Keyword.has_key?(keys, :field_a)
      assert Keyword.has_key?(keys, :field_b)
      assert Keyword.has_key?(keys, :field_c)
      assert Keyword.get(keys, :field_b)[:required] == true
    end

    test "handles complex schema merge" do
      generated = [
        extractions: [
          type: {:list, :map},
          default: []
        ]
      ]

      user = [
        extractions: [
          type: {:list, :map},
          required: true,
          doc: "Custom documentation"
        ]
      ]

      merged = Schema.merge(generated, user)

      assert merged[:extractions][:required] == true
      assert merged[:extractions][:doc] == "Custom documentation"
      assert merged[:extractions][:type] == {:list, :map}
    end

    test "handles empty generated schema" do
      generated = []

      user = [
        field: [type: :string]
      ]

      merged = Schema.merge(generated, user)

      assert merged == user
    end

    test "handles empty user schema" do
      generated = [
        field: [type: :string]
      ]

      user = []

      merged = Schema.merge(generated, user)

      assert merged == generated
    end
  end

  describe "integration tests" do
    test "generates and validates medical extraction schema" do
      examples = [
        %ExampleData{
          input: "Patient takes aspirin 81mg daily",
          output: %{
            "extractions" => [
              %{
                "class" => "Medication",
                "medication_attributes" => %{
                  "name" => "aspirin",
                  "dosage" => "81mg",
                  "frequency" => "daily"
                }
              }
            ]
          }
        },
        %ExampleData{
          input: "Dr. Smith prescribed ibuprofen 200mg",
          output: %{
            "extractions" => [
              %{
                "class" => "Person",
                "person_attributes" => %{"name" => "Dr. Smith"}
              },
              %{
                "class" => "Medication",
                "medication_attributes" => %{"name" => "ibuprofen", "dosage" => "200mg"}
              }
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:type] == {:list, :map}
    end

    test "generates schema and merges with user overrides" do
      examples = [
        %ExampleData{
          input: "Test entity",
          output: %{
            "extractions" => [
              %{"class" => "Entity", "entity_attributes" => %{"name" => "test"}}
            ]
          }
        }
      ]

      user_schema = [
        extractions: [
          required: true,
          doc: "Required extractions list"
        ]
      ]

      schema = Schema.from_examples(examples, manual_schema: user_schema)

      assert schema[:extractions][:required] == true
      assert schema[:extractions][:doc] == "Required extractions list"

      data = []
      assert {:error, _} = Schema.validate(data, schema)
    end

    test "end-to-end: examples to schema to validation" do
      examples = [
        %ExampleData{
          input: "Order #123 for John",
          output: %{
            "extractions" => [
              %{"class" => "Order", "order_attributes" => %{"order_id" => "123"}},
              %{"class" => "Person", "person_attributes" => %{"name" => "John"}}
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:type] == {:list, :map}
    end

    test "handles real-world complex multi-class extraction" do
      examples = [
        %ExampleData{
          input: "Dr. Smith ordered test #12345 for patient John Doe, prescribed aspirin 81mg",
          output: %{
            "extractions" => [
              %{"class" => "Doctor", "doctor_attributes" => %{"name" => "Dr. Smith"}},
              %{"class" => "LabOrder", "lab_order_attributes" => %{"order_id" => "12345"}},
              %{"class" => "Patient", "patient_attributes" => %{"name" => "John Doe"}},
              %{
                "class" => "Medication",
                "medication_attributes" => %{"name" => "aspirin", "dosage" => "81mg"}
              }
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:type] == {:list, :map}
      assert Keyword.has_key?(schema[:extractions], :keys)
    end
  end
end
