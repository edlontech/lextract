defmodule LeXtract.FormatTypeTest do
  use ExUnit.Case, async: true
  doctest LeXtract.FormatType

  alias LeXtract.FormatType

  describe "from_string/1" do
    test "converts 'json' to :json atom" do
      assert {:ok, :json} = FormatType.from_string("json")
    end

    test "converts 'yaml' to :yaml atom" do
      assert {:ok, :yaml} = FormatType.from_string("yaml")
    end

    test "converts 'yml' to :yaml atom" do
      assert {:ok, :yaml} = FormatType.from_string("yml")
    end

    test "returns error for unknown format" do
      assert {:error, error} = FormatType.from_string("xml")
      assert %LeXtract.Error.Invalid.Format{} = error
      assert error.format_string == "xml"
    end

    test "returns error for empty string" do
      assert {:error, error} = FormatType.from_string("")
      assert %LeXtract.Error.Invalid.Format{} = error
      assert error.format_string == ""
    end

    test "returns error for uppercase format" do
      assert {:error, error} = FormatType.from_string("JSON")
      assert %LeXtract.Error.Invalid.Format{} = error
      assert error.format_string == "JSON"
    end

    test "returns error for mixed case format" do
      assert {:error, error} = FormatType.from_string("Json")
      assert %LeXtract.Error.Invalid.Format{} = error
      assert error.format_string == "Json"
    end

    test "returns error for format with whitespace" do
      assert {:error, error} = FormatType.from_string(" json ")
      assert %LeXtract.Error.Invalid.Format{} = error
      assert error.format_string == " json "
    end
  end

  describe "to_string/1" do
    test "converts :json atom to 'json' string" do
      assert "json" = FormatType.to_string(:json)
    end

    test "converts :yaml atom to 'yaml' string" do
      assert "yaml" = FormatType.to_string(:yaml)
    end
  end

  describe "all/0" do
    test "returns list of all format types" do
      assert [:json, :yaml] = FormatType.all()
    end

    test "all formats can round-trip through to_string and from_string" do
      for format <- FormatType.all() do
        string = FormatType.to_string(format)
        assert {:ok, ^format} = FormatType.from_string(string)
      end
    end

    test "returns exactly two format types" do
      assert length(FormatType.all()) == 2
    end

    test "all returned formats are atoms" do
      for format <- FormatType.all() do
        assert is_atom(format)
      end
    end
  end

  describe "integration" do
    test "supports common workflow of string to atom to string" do
      assert {:ok, format} = FormatType.from_string("json")
      assert "json" = FormatType.to_string(format)
    end

    test "yml alias works in full workflow" do
      assert {:ok, format} = FormatType.from_string("yml")
      assert "yaml" = FormatType.to_string(format)
    end
  end
end
