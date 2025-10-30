defmodule LeXtract.Schema.AnalyzerTest do
  use ExUnit.Case, async: true

  alias LeXtract.ExampleData
  alias LeXtract.Schema.Analyzer

  doctest LeXtract.Schema.Analyzer

  describe "analyze/1" do
    test "analyzes single medication example" do
      examples = [
        %ExampleData{
          input: "Patient takes aspirin 100mg daily",
          output: %{
            "extractions" => [
              %{
                "class" => "Medication",
                "medication_attributes" => %{
                  "name" => "aspirin",
                  "dosage" => "100mg"
                }
              }
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.classes == ["Medication"]
      assert result.attributes["Medication"] == ["dosage", "name"]
      assert result.types["Medication.name"] == :string
      assert result.types["Medication.dosage"] == :string
    end

    test "analyzes multiple extraction classes" do
      examples = [
        %ExampleData{
          input: "Dr. Smith prescribed aspirin to John Doe",
          output: %{
            "extractions" => [
              %{
                "class" => "Person",
                "person_attributes" => %{"name" => "Dr. Smith", "role" => "doctor"}
              },
              %{
                "class" => "Medication",
                "medication_attributes" => %{"name" => "aspirin"}
              },
              %{
                "class" => "Person",
                "person_attributes" => %{"name" => "John Doe", "role" => "patient"}
              }
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert Enum.sort(result.classes) == ["Medication", "Person"]
      assert Enum.sort(result.attributes["Person"]) == ["name", "role"]
      assert result.attributes["Medication"] == ["name"]
    end

    test "handles multi-word class names with camel case" do
      examples = [
        %ExampleData{
          input: "Test order ID: 12345",
          output: %{
            "extractions" => [
              %{
                "class" => "LabOrder",
                "lab_order_attributes" => %{"order_id" => "12345"}
              }
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.classes == ["LabOrder"]
      assert result.attributes["LabOrder"] == ["order_id"]
    end

    test "infers different attribute types" do
      examples = [
        %ExampleData{
          input: "Test data with various types",
          output: %{
            "extractions" => [
              %{
                "class" => "Data",
                "data_attributes" => %{
                  "text_field" => "hello",
                  "number_field" => 42,
                  "float_field" => 3.14,
                  "boolean_field" => true,
                  "list_field" => ["a", "b", "c"],
                  "map_field" => %{"key" => "value"}
                }
              }
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.types["Data.text_field"] == :string
      assert result.types["Data.number_field"] == :integer
      assert result.types["Data.float_field"] == :float
      assert result.types["Data.boolean_field"] == :boolean
      assert result.types["Data.list_field"] == {:list, :string}
      assert result.types["Data.map_field"] == :map
    end

    test "handles empty examples" do
      result = Analyzer.analyze([])

      assert result.classes == []
      assert result.attributes == %{}
      assert result.types == %{}
    end

    test "handles examples with no extractions" do
      examples = [
        %ExampleData{
          input: "No entities here",
          output: %{"extractions" => []}
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.classes == []
      assert result.attributes == %{}
      assert result.types == %{}
    end

    test "handles extractions without attributes" do
      examples = [
        %ExampleData{
          input: "Simple extraction",
          output: %{
            "extractions" => [
              %{"class" => "Entity"}
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.classes == ["Entity"]
      assert result.attributes["Entity"] == []
      assert result.types == %{}
    end

    test "merges attributes from multiple examples" do
      examples = [
        %ExampleData{
          input: "First example",
          output: %{
            "extractions" => [
              %{
                "class" => "Person",
                "person_attributes" => %{"name" => "Alice"}
              }
            ]
          }
        },
        %ExampleData{
          input: "Second example",
          output: %{
            "extractions" => [
              %{
                "class" => "Person",
                "person_attributes" => %{"name" => "Bob", "age" => 30}
              }
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.classes == ["Person"]
      assert Enum.sort(result.attributes["Person"]) == ["age", "name"]
    end

    test "handles nested list types" do
      examples = [
        %ExampleData{
          input: "Nested list example",
          output: %{
            "extractions" => [
              %{
                "class" => "Data",
                "data_attributes" => %{
                  "number_list" => [1, 2, 3],
                  "bool_list" => [true, false]
                }
              }
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.types["Data.number_list"] == {:list, :integer}
      assert result.types["Data.bool_list"] == {:list, :boolean}
    end

    test "defaults to string type for missing attributes" do
      examples = [
        %ExampleData{
          input: "Example one",
          output: %{
            "extractions" => [
              %{
                "class" => "Entity",
                "entity_attributes" => %{"field_a" => "value"}
              }
            ]
          }
        },
        %ExampleData{
          input: "Example two",
          output: %{
            "extractions" => [
              %{
                "class" => "Entity",
                "entity_attributes" => %{"field_b" => "value"}
              }
            ]
          }
        }
      ]

      result = Analyzer.analyze(examples)

      assert result.types["Entity.field_a"] == :string
      assert result.types["Entity.field_b"] == :string
    end
  end

  describe "to_nimble_options/1" do
    test "converts schema info to simple NimbleOptions format" do
      schema_info = %{
        classes: ["Medication"],
        attributes: %{"Medication" => ["name", "dosage"]},
        types: %{
          "Medication.name" => :string,
          "Medication.dosage" => :string
        }
      }

      schema = Analyzer.to_nimble_options(schema_info)

      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:type] == {:list, :map}
      assert schema[:extractions][:default] == []
      assert schema[:extractions][:doc] == "List of extracted entities"
    end

    test "generates same schema format regardless of complexity" do
      schema_info = %{
        classes: ["Medication", "Person", "Lab Order"],
        attributes: %{
          "Medication" => ["name", "dosage", "frequency"],
          "Person" => ["name", "role"],
          "LabOrder" => ["order_id"]
        },
        types: %{
          "Medication.name" => :string,
          "Medication.dosage" => :string,
          "Medication.frequency" => :string,
          "Person.name" => :string,
          "Person.role" => :string,
          "LabOrder.order_id" => :string
        }
      }

      schema = Analyzer.to_nimble_options(schema_info)

      assert schema[:extractions][:type] == {:list, :map}
      assert schema[:extractions][:default] == []
    end

    test "handles empty schema info" do
      schema_info = %{
        classes: [],
        attributes: %{},
        types: %{}
      }

      schema = Analyzer.to_nimble_options(schema_info)

      assert schema[:extractions][:type] == {:list, :map}
      assert schema[:extractions][:default] == []
    end

    test "generates documentation" do
      schema_info = %{
        classes: ["Entity"],
        attributes: %{"Entity" => ["field"]},
        types: %{"Entity.field" => :string}
      }

      schema = Analyzer.to_nimble_options(schema_info)

      assert schema[:extractions][:doc] == "List of extracted entities"
    end
  end

  describe "integration tests" do
    test "end-to-end medical extraction schema" do
      examples = [
        %ExampleData{
          input: "Patient takes aspirin 81mg daily for heart health",
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
          input: "Dr. Smith prescribed ibuprofen 200mg as needed",
          output: %{
            "extractions" => [
              %{
                "class" => "Person",
                "person_attributes" => %{"name" => "Dr. Smith", "role" => "doctor"}
              },
              %{
                "class" => "Medication",
                "medication_attributes" => %{
                  "name" => "ibuprofen",
                  "dosage" => "200mg",
                  "frequency" => "as needed"
                }
              }
            ]
          }
        }
      ]

      schema_info = Analyzer.analyze(examples)

      assert Enum.sort(schema_info.classes) == ["Medication", "Person"]
      assert Enum.sort(schema_info.attributes["Medication"]) == ["dosage", "frequency", "name"]
      assert Enum.sort(schema_info.attributes["Person"]) == ["name", "role"]

      schema = Analyzer.to_nimble_options(schema_info)

      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:default] == []
    end

    test "handles real-world complex extraction scenario" do
      examples = [
        %ExampleData{
          input: "Order #12345 for patient John Doe, prescribed aspirin 81mg",
          output: %{
            "extractions" => [
              %{
                "class" => "Order",
                "order_attributes" => %{"order_id" => "12345"}
              },
              %{
                "class" => "Patient",
                "patient_attributes" => %{"name" => "John Doe"}
              },
              %{
                "class" => "Medication",
                "medication_attributes" => %{"name" => "aspirin", "dosage" => "81mg"}
              }
            ]
          }
        }
      ]

      schema_info = Analyzer.analyze(examples)
      schema = Analyzer.to_nimble_options(schema_info)

      assert length(schema_info.classes) == 3
      assert Keyword.has_key?(schema, :extractions)
      assert schema[:extractions][:type] == {:list, :map}
    end
  end
end
