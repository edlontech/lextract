defmodule LeXtract.FormatHandlerTest do
  use ExUnit.Case, async: true
  doctest LeXtract.FormatHandler

  alias LeXtract.FormatHandler

  describe "parse/2 with JSON" do
    test "parses valid JSON object" do
      json = ~s({"name": "John", "age": 30})
      assert {:ok, %{"name" => "John", "age" => 30}} = FormatHandler.parse(json, :json)
    end

    test "parses valid JSON array" do
      json = ~s([1, 2, 3])
      assert {:ok, [1, 2, 3]} = FormatHandler.parse(json, :json)
    end

    test "parses empty JSON object" do
      json = ~s({})
      assert {:ok, %{}} = FormatHandler.parse(json, :json)
    end

    test "parses empty JSON array" do
      json = ~s([])
      assert {:ok, []} = FormatHandler.parse(json, :json)
    end

    test "parses nested JSON structure" do
      json = ~s({"user": {"name": "John", "address": {"city": "NYC"}}})

      assert {:ok, %{"user" => %{"name" => "John", "address" => %{"city" => "NYC"}}}} =
               FormatHandler.parse(json, :json)
    end

    test "parses JSON with null values" do
      json = ~s({"value": null})
      assert {:ok, %{"value" => nil}} = FormatHandler.parse(json, :json)
    end

    test "parses JSON with boolean values" do
      json = ~s({"active": true, "deleted": false})
      assert {:ok, %{"active" => true, "deleted" => false}} = FormatHandler.parse(json, :json)
    end

    test "parses JSON with unicode characters" do
      json = ~s({"name": "José", "emoji": "🎉"})
      assert {:ok, %{"name" => "José", "emoji" => "🎉"}} = FormatHandler.parse(json, :json)
    end

    test "returns error for invalid JSON" do
      json = "{invalid json}"
      assert {:error, %LeXtract.Error.Processing.Parsing{}} = FormatHandler.parse(json, :json)
    end

    test "returns error for incomplete JSON object" do
      json = ~s({"key": "value")
      assert {:error, %LeXtract.Error.Processing.Parsing{}} = FormatHandler.parse(json, :json)
    end

    test "returns error for malformed JSON array" do
      json = ~s([1, 2,)
      assert {:error, %LeXtract.Error.Processing.Parsing{}} = FormatHandler.parse(json, :json)
    end
  end

  describe "parse/2 with YAML" do
    test "parses valid YAML map" do
      yaml = "name: John\nage: 30"
      assert {:ok, %{"name" => "John", "age" => 30}} = FormatHandler.parse(yaml, :yaml)
    end

    test "parses valid YAML array" do
      yaml = "- item1\n- item2\n- item3"
      assert {:ok, ["item1", "item2", "item3"]} = FormatHandler.parse(yaml, :yaml)
    end

    test "parses empty YAML map" do
      yaml = "{}"
      assert {:ok, %{}} = FormatHandler.parse(yaml, :yaml)
    end

    test "parses YAML with nested structure" do
      yaml = """
      user:
        name: John
        address:
          city: NYC
      """

      assert {:ok, %{"user" => %{"name" => "John", "address" => %{"city" => "NYC"}}}} =
               FormatHandler.parse(yaml, :yaml)
    end

    test "parses YAML with null values" do
      yaml = "value: ~"
      assert {:ok, %{"value" => nil}} = FormatHandler.parse(yaml, :yaml)
    end

    test "parses YAML with boolean values" do
      yaml = "active: true\ndeleted: false"
      assert {:ok, %{"active" => true, "deleted" => false}} = FormatHandler.parse(yaml, :yaml)
    end

    test "parses YAML with unicode characters" do
      yaml = "name: José\nemoji: 🎉"
      assert {:ok, %{"name" => "José", "emoji" => "🎉"}} = FormatHandler.parse(yaml, :yaml)
    end

    test "returns error for invalid YAML" do
      yaml = ":\n  invalid: yaml: structure"
      assert {:error, %LeXtract.Error.Processing.Parsing{}} = FormatHandler.parse(yaml, :yaml)
    end
  end

  describe "parse/2 with fenced JSON" do
    test "parses fenced JSON with json tag" do
      fenced = """
      ```json
      {"name": "John"}
      ```
      """

      assert {:ok, %{"name" => "John"}} = FormatHandler.parse(fenced, :json)
    end

    test "parses fenced JSON with extra whitespace" do
      fenced = """
      ```json

      {"value": 42}

      ```
      """

      assert {:ok, %{"value" => 42}} = FormatHandler.parse(fenced, :json)
    end

    test "parses fenced JSON array" do
      fenced = """
      ```json
      [1, 2, 3]
      ```
      """

      assert {:ok, [1, 2, 3]} = FormatHandler.parse(fenced, :json)
    end

    test "parses multiline fenced JSON" do
      fenced = """
      ```json
      {
        "name": "John",
        "age": 30,
        "address": {
          "city": "NYC"
        }
      }
      ```
      """

      assert {:ok, %{"name" => "John", "age" => 30, "address" => %{"city" => "NYC"}}} =
               FormatHandler.parse(fenced, :json)
    end
  end

  describe "parse/2 with fenced YAML" do
    test "parses fenced YAML with yaml tag" do
      fenced = """
      ```yaml
      name: John
      ```
      """

      assert {:ok, %{"name" => "John"}} = FormatHandler.parse(fenced, :yaml)
    end

    test "parses fenced YAML with yml tag" do
      fenced = """
      ```yml
      name: John
      ```
      """

      assert {:ok, %{"name" => "John"}} = FormatHandler.parse(fenced, :yaml)
    end

    test "parses fenced YAML array" do
      fenced = """
      ```yaml
      - item1
      - item2
      ```
      """

      assert {:ok, ["item1", "item2"]} = FormatHandler.parse(fenced, :yaml)
    end

    test "parses multiline fenced YAML" do
      fenced = """
      ```yaml
      user:
        name: John
        age: 30
        address:
          city: NYC
      ```
      """

      assert {:ok, %{"user" => %{"name" => "John", "age" => 30, "address" => %{"city" => "NYC"}}}} =
               FormatHandler.parse(fenced, :yaml)
    end
  end

  describe "fenced?/2" do
    test "returns true for fenced JSON" do
      fenced = "```json\n{}\n```"
      assert FormatHandler.fenced?(fenced, :json)
    end

    test "returns false for unfenced JSON" do
      unfenced = "{}"
      refute FormatHandler.fenced?(unfenced, :json)
    end

    test "returns true for fenced YAML with yaml tag" do
      fenced = "```yaml\nkey: value\n```"
      assert FormatHandler.fenced?(fenced, :yaml)
    end

    test "returns true for fenced YAML with yml tag" do
      fenced = "```yml\nkey: value\n```"
      assert FormatHandler.fenced?(fenced, :yaml)
    end

    test "returns false for unfenced YAML" do
      unfenced = "key: value"
      refute FormatHandler.fenced?(unfenced, :yaml)
    end

    test "returns false for JSON when checking YAML fence" do
      json_fenced = "```json\n{}\n```"
      refute FormatHandler.fenced?(json_fenced, :yaml)
    end

    test "returns false for YAML when checking JSON fence" do
      yaml_fenced = "```yaml\nkey: value\n```"
      refute FormatHandler.fenced?(yaml_fenced, :json)
    end

    test "handles fence with extra whitespace" do
      fenced = "```json  \n{}\n```"
      assert FormatHandler.fenced?(fenced, :json)
    end
  end

  describe "extract_fenced_content/2" do
    test "extracts JSON content from fences" do
      fenced = ~S(```json
{"key": "value"}
```)
      assert ~s({"key": "value"}) = FormatHandler.extract_fenced_content(fenced, :json)
    end

    test "returns unfenced JSON unchanged" do
      unfenced = ~s({"key": "value"})
      assert ^unfenced = FormatHandler.extract_fenced_content(unfenced, :json)
    end

    test "extracts YAML content from yaml fences" do
      fenced = "```yaml\nkey: value\n```"
      assert "key: value" = FormatHandler.extract_fenced_content(fenced, :yaml)
    end

    test "extracts YAML content from yml fences" do
      fenced = "```yml\nkey: value\n```"
      assert "key: value" = FormatHandler.extract_fenced_content(fenced, :yaml)
    end

    test "returns unfenced YAML unchanged" do
      unfenced = "key: value"
      assert ^unfenced = FormatHandler.extract_fenced_content(unfenced, :yaml)
    end

    test "trims whitespace from extracted content" do
      fenced = ~S(```json
  {"key": "value"}
```)
      assert ~s({"key": "value"}) = FormatHandler.extract_fenced_content(fenced, :json)
    end

    test "handles multiline content" do
      fenced = """
      ```json
      {
        "key": "value"
      }
      ```
      """

      extracted = FormatHandler.extract_fenced_content(fenced, :json)
      assert extracted =~ "\"key\""
      assert extracted =~ "\"value\""
    end
  end

  describe "valid?/2" do
    test "returns true for valid JSON" do
      assert FormatHandler.valid?(~s({"key": "value"}), :json)
    end

    test "returns false for invalid JSON" do
      refute FormatHandler.valid?("{invalid}", :json)
    end

    test "returns true for valid YAML" do
      assert FormatHandler.valid?("key: value", :yaml)
    end

    test "returns false for invalid YAML" do
      refute FormatHandler.valid?(":\n  invalid: yaml: structure", :yaml)
    end

    test "returns true for fenced valid JSON" do
      fenced = ~S(```json
{"key": "value"}
```)
      assert FormatHandler.valid?(fenced, :json)
    end

    test "returns true for fenced valid YAML" do
      assert FormatHandler.valid?("```yaml\nkey: value\n```", :yaml)
    end

    test "returns false for fenced invalid JSON" do
      refute FormatHandler.valid?("```json\n{invalid}\n```", :json)
    end

    test "returns true for empty JSON object" do
      assert FormatHandler.valid?("{}", :json)
    end

    test "returns true for empty JSON array" do
      assert FormatHandler.valid?("[]", :json)
    end
  end

  describe "edge cases" do
    test "handles JSON with escaped quotes" do
      json = ~s({"text": "He said \\"hello\\""})
      assert {:ok, %{"text" => "He said \"hello\""}} = FormatHandler.parse(json, :json)
    end

    test "handles JSON with special characters" do
      json = ~s({"path": "C:\\\\Users\\\\file.txt"})
      assert {:ok, %{"path" => "C:\\Users\\file.txt"}} = FormatHandler.parse(json, :json)
    end

    test "handles large JSON structure" do
      items = for i <- 1..100, do: ~s("item#{i}")
      json = "[#{Enum.join(items, ", ")}]"
      assert {:ok, list} = FormatHandler.parse(json, :json)
      assert length(list) == 100
    end

    test "handles YAML with indentation" do
      yaml = """
        name: John
        age: 30
      """

      assert {:ok, %{"name" => "John", "age" => 30}} = FormatHandler.parse(yaml, :yaml)
    end

    test "handles empty string" do
      assert {:error, _} = FormatHandler.parse("", :json)
      assert {:ok, %{}} = FormatHandler.parse("", :yaml)
    end

    test "handles whitespace-only string" do
      assert {:error, _} = FormatHandler.parse("   \n  \t  ", :json)
    end
  end

  describe "integration" do
    test "full workflow: detect fence, extract, parse JSON" do
      fenced = """
      ```json
      {
        "person": "John Doe",
        "person_index": 0
      }
      ```
      """

      assert FormatHandler.fenced?(fenced, :json)
      extracted = FormatHandler.extract_fenced_content(fenced, :json)

      assert {:ok, %{"person" => "John Doe", "person_index" => 0}} =
               FormatHandler.parse(extracted, :json)
    end

    test "full workflow: detect fence, extract, parse YAML" do
      fenced = """
      ```yaml
      person: John Doe
      person_index: 0
      ```
      """

      assert FormatHandler.fenced?(fenced, :yaml)
      extracted = FormatHandler.extract_fenced_content(fenced, :yaml)

      assert {:ok, %{"person" => "John Doe", "person_index" => 0}} =
               FormatHandler.parse(extracted, :yaml)
    end

    test "parse handles fence extraction automatically" do
      fenced = """
      ```json
      {"value": 42}
      ```
      """

      assert {:ok, %{"value" => 42}} = FormatHandler.parse(fenced, :json)
    end
  end
end
