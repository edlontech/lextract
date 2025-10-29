defmodule LeXtract.ExtractionTest do
  use ExUnit.Case, async: true
  doctest LeXtract.Extraction

  alias LeXtract.{CharInterval, Extraction, TokenInterval}

  describe "struct creation" do
    test "creates extraction with required fields" do
      extraction = %Extraction{extraction_class: "person", extraction_text: "John Doe"}

      assert extraction.extraction_class == "person"
      assert extraction.extraction_text == "John Doe"
      assert is_nil(extraction.char_interval)
      assert is_nil(extraction.alignment_status)
      assert is_nil(extraction.extraction_index)
      assert is_nil(extraction.group_index)
      assert is_nil(extraction.description)
      assert is_nil(extraction.attributes)
      assert is_nil(extraction.token_interval)
    end

    test "accepts optional fields" do
      interval = CharInterval.new(0, 8)
      token_interval = TokenInterval.new(0, 2)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: "John Doe",
        char_interval: interval,
        alignment_status: :exact,
        extraction_index: 0,
        group_index: 1,
        description: "A person's name",
        attributes: %{age: "30"},
        token_interval: token_interval
      }

      assert extraction.char_interval == interval
      assert extraction.alignment_status == :exact
      assert extraction.extraction_index == 0
      assert extraction.group_index == 1
      assert extraction.description == "A person's name"
      assert extraction.attributes == %{age: "30"}
      assert extraction.token_interval == token_interval
    end

    test "accepts partial optional fields" do
      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: "aspirin",
        extraction_index: 0,
        attributes: %{dosage: "81mg"}
      }

      assert extraction.extraction_class == "medication"
      assert extraction.extraction_text == "aspirin"
      assert extraction.extraction_index == 0
      assert extraction.attributes == %{dosage: "81mg"}
      assert is_nil(extraction.char_interval)
    end
  end

  describe "aligned?/1" do
    test "returns false when char_interval is nil" do
      extraction = %Extraction{extraction_class: "person", extraction_text: "John Doe"}

      refute Extraction.aligned?(extraction)
    end

    test "returns true when char_interval is present" do
      interval = CharInterval.new(0, 8)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: "John Doe",
        char_interval: interval
      }

      assert Extraction.aligned?(extraction)
    end

    test "returns true for zero-length interval" do
      interval = CharInterval.new(5, 5)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: "John Doe",
        char_interval: interval
      }

      assert Extraction.aligned?(extraction)
    end
  end

  describe "has_attributes?/1" do
    test "returns false when attributes is nil" do
      extraction = %Extraction{extraction_class: "person", extraction_text: "John Doe"}

      refute Extraction.has_attributes?(extraction)
    end

    test "returns false when attributes is empty map" do
      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: "John Doe",
        attributes: %{}
      }

      refute Extraction.has_attributes?(extraction)
    end

    test "returns true when attributes has values" do
      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: "John Doe",
        attributes: %{age: "30"}
      }

      assert Extraction.has_attributes?(extraction)
    end

    test "returns true for multiple attributes" do
      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: "aspirin",
        attributes: %{dosage: "81mg", frequency: "daily"}
      }

      assert Extraction.has_attributes?(extraction)
    end
  end

  describe "struct fields" do
    test "enforces required extraction_class field" do
      assert_raise ArgumentError, fn ->
        struct!(Extraction, extraction_text: "test")
      end
    end

    test "enforces required extraction_text field" do
      assert_raise ArgumentError, fn ->
        struct!(Extraction, extraction_class: "entity")
      end
    end

    test "enforces both required fields" do
      assert_raise ArgumentError, fn ->
        struct!(Extraction, [])
      end
    end

    test "allows empty strings for required fields" do
      extraction = %Extraction{extraction_class: "", extraction_text: ""}

      assert extraction.extraction_class == ""
      assert extraction.extraction_text == ""
    end
  end

  describe "integration" do
    test "creates fully populated extraction" do
      char_interval = CharInterval.new(10, 25)
      token_interval = TokenInterval.new(2, 5)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: "aspirin 81mg daily",
        char_interval: char_interval,
        token_interval: token_interval,
        alignment_status: :exact,
        extraction_index: 0,
        group_index: 0,
        description: "Patient medication",
        attributes: %{
          drug: "aspirin",
          dosage: "81mg",
          frequency: "daily"
        }
      }

      assert Extraction.aligned?(extraction)
      assert Extraction.has_attributes?(extraction)
      assert extraction.extraction_class == "medication"
      assert extraction.extraction_text == "aspirin 81mg daily"
      assert extraction.alignment_status == :exact
      assert extraction.attributes.drug == "aspirin"
    end
  end
end
