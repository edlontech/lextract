defmodule LeXtract.ConfigTest do
  use ExUnit.Case, async: true
  doctest LeXtract.Config

  alias LeXtract.Config

  describe "default/0" do
    test "returns config with default values" do
      config = Config.default()

      assert config.max_char_buffer == 1000
      assert config.chunk_overlap == 200
      assert config.format == :yaml
      assert config.batch_size == 5
      assert config.max_concurrency == 8
      assert config.attribute_suffix == "_attributes"
    end
  end

  describe "new/1" do
    test "creates config with custom values" do
      config = Config.new(prompt: "test", max_char_buffer: 2000)

      assert config.prompt == "test"
      assert config.max_char_buffer == 2000
    end

    test "merges with defaults" do
      config = Config.new(prompt: "test")

      assert config.prompt == "test"
      assert config.batch_size == 5
      assert config.max_concurrency == 8
    end

    test "sets format" do
      config = Config.new(prompt: "test", format: :json)

      assert config.format == :json
    end

    test "raises for non-positive max_char_buffer" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(prompt: "test", max_char_buffer: 0)
      end
    end

    test "raises for negative max_char_buffer" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(prompt: "test", max_char_buffer: -1)
      end
    end

    test "raises for invalid format" do
      assert_raise NimbleOptions.ValidationError, ~r/expected one of \[:json, :yaml\]/, fn ->
        Config.new(prompt: "test", format: :xml)
      end
    end

    test "raises for non-positive batch_size" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(prompt: "test", batch_size: 0)
      end
    end

    test "raises for non-positive max_concurrency" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(prompt: "test", max_concurrency: -5)
      end
    end

    test "raises for unknown keys" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Config.new(prompt: "test", unknown_key: "value")
      end
    end

    test "raises for model and provider since they are no longer core options" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Config.new(prompt: "test", model: "gpt-4", provider: :openai)
      end
    end
  end

  describe "validate/1 with keyword list" do
    test "returns {:ok, config} for valid options" do
      assert {:ok, config} =
               Config.validate(prompt: "test", max_char_buffer: 1000)

      assert %Config{} = config
      assert config.max_char_buffer == 1000
    end

    test "returns error for non-positive max_char_buffer" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(prompt: "test", max_char_buffer: 0)
    end

    test "returns error for negative max_char_buffer" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(prompt: "test", max_char_buffer: -1)
    end

    test "returns error for invalid format" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(prompt: "test", format: :xml)
    end

    test "validates all fields together" do
      assert {:ok, config} =
               Config.validate(prompt: "test", max_char_buffer: 2000, batch_size: 5)

      assert config.max_char_buffer == 2000
      assert config.batch_size == 5
    end

    test "returns error for model and provider since they are no longer core options" do
      assert {:error, %LeXtract.Error.Invalid.Config{} = error} =
               Config.validate(prompt: "test", model: "gpt-4", provider: :openai)

      assert Exception.message(error) =~ "unknown options"
    end
  end

  describe "validate/1 with struct" do
    test "returns {:ok, config} for valid config struct" do
      config = Config.new(prompt: "test")

      assert {:ok, validated_config} = Config.validate(config)
      assert validated_config.prompt == config.prompt
    end

    test "re-validates struct fields" do
      %Config{} = base_config = Config.new(prompt: "test")
      config = %{base_config | max_char_buffer: -1}

      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(config)
    end
  end

  describe "validate!/1" do
    test "returns config for valid options" do
      config = Config.validate!(prompt: "test", max_char_buffer: 1000)

      assert %Config{} = config
      assert config.max_char_buffer == 1000
    end

    test "raises for invalid max_char_buffer" do
      assert_raise LeXtract.Error.Invalid.Config, ~r/expected positive integer/, fn ->
        Config.validate!(prompt: "test", max_char_buffer: -1)
      end
    end

    test "raises for invalid format" do
      assert_raise LeXtract.Error.Invalid.Config, ~r/expected one of \[:json, :yaml\]/, fn ->
        Config.validate!(prompt: "test", format: :csv)
      end
    end

    test "accepts valid struct" do
      config = Config.new(prompt: "test")

      validated = Config.validate!(config)
      assert validated.prompt == config.prompt
    end
  end
end
