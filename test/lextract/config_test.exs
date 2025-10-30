defmodule LeXtract.ConfigTest do
  use ExUnit.Case, async: true
  doctest LeXtract.Config

  alias LeXtract.Config

  describe "default/0" do
    test "returns config with default values" do
      config = Config.default()

      assert config.model == nil
      assert config.provider == nil
      assert config.api_key == nil
      assert config.max_char_buffer == 1000
      assert config.chunk_overlap == 200
      assert config.temperature == nil
      assert config.format == :yaml
      assert config.batch_size == 5
      assert config.max_concurrency == 8
      assert config.timeout == 60_000
      assert config.attribute_suffix == "_attributes"
    end
  end

  describe "new/1" do
    test "creates config with custom values" do
      config =
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: 2000)

      assert config.model == "gpt-4"
      assert config.max_char_buffer == 2000
    end

    test "merges with defaults" do
      config = Config.new(model: "gpt-4", provider: :openai, prompt: "test")

      assert config.model == "gpt-4"
      assert config.batch_size == 5
      assert config.max_concurrency == 8
    end

    test "creates config with minimal required fields" do
      config = Config.new(model: "gpt-4", provider: :openai, prompt: "test")

      assert config.model == "gpt-4"
      assert config.provider == :openai
      assert config.prompt == "test"
    end

    test "sets temperature" do
      config = Config.new(model: "gpt-4", provider: :openai, prompt: "test", temperature: 0.7)

      assert config.temperature == 0.7
    end

    test "sets format" do
      config = Config.new(model: "gpt-4", provider: :openai, prompt: "test", format: :json)

      assert config.format == :json
    end

    test "raises for non-positive max_char_buffer" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: 0)
      end
    end

    test "raises for negative max_char_buffer" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: -1)
      end
    end

    test "raises for temperature below 0.0" do
      assert_raise NimbleOptions.ValidationError, ~r/must be a float between 0.0 and 1.0/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", temperature: -0.1)
      end
    end

    test "raises for temperature above 1.0" do
      assert_raise NimbleOptions.ValidationError, ~r/must be a float between 0.0 and 1.0/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", temperature: 1.1)
      end
    end

    test "raises for invalid format" do
      assert_raise NimbleOptions.ValidationError, ~r/expected one of \[:json, :yaml\]/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", format: :xml)
      end
    end

    test "raises for non-positive batch_size" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", batch_size: 0)
      end
    end

    test "raises for non-positive max_concurrency" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", max_concurrency: -5)
      end
    end

    test "raises for invalid timeout" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", timeout: -100)
      end
    end

    test "accepts valid timeout" do
      config = Config.new(model: "gpt-4", provider: :openai, prompt: "test", timeout: 30_000)

      assert config.timeout == 30_000
    end

    test "raises for unknown keys" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Config.new(model: "gpt-4", provider: :openai, prompt: "test", unknown_key: "value")
      end
    end
  end

  describe "validate/1 with keyword list" do
    test "returns {:ok, config} for valid options" do
      assert {:ok, config} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 max_char_buffer: 1000
               )

      assert %Config{} = config
      assert config.max_char_buffer == 1000
    end

    test "returns error for non-positive max_char_buffer" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 max_char_buffer: 0
               )
    end

    test "returns error for negative max_char_buffer" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 max_char_buffer: -1
               )
    end

    test "returns error for temperature below 0.0" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 temperature: -0.1
               )
    end

    test "returns error for temperature above 1.0" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 temperature: 1.1
               )
    end

    test "returns error for invalid format" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(model: "gpt-4", provider: :openai, prompt: "test", format: :xml)
    end

    test "accepts temperature of 0.0" do
      assert {:ok, config} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 temperature: 0.0
               )

      assert config.temperature == 0.0
    end

    test "accepts temperature of 1.0" do
      assert {:ok, config} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 temperature: 1.0
               )

      assert config.temperature == 1.0
    end

    test "accepts nil temperature" do
      assert {:ok, config} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 temperature: nil
               )

      assert config.temperature == nil
    end

    test "validates all fields together" do
      assert {:ok, config} =
               Config.validate(
                 model: "gpt-4",
                 provider: :openai,
                 prompt: "test",
                 max_char_buffer: 2000,
                 temperature: 0.5,
                 batch_size: 5
               )

      assert config.max_char_buffer == 2000
      assert config.temperature == 0.5
      assert config.batch_size == 5
    end
  end

  describe "validate/1 with struct" do
    test "returns {:ok, config} for valid config struct" do
      config = Config.new(model: "gpt-4", provider: :openai, prompt: "test")

      assert {:ok, validated_config} = Config.validate(config)
      assert validated_config.model == config.model
      assert validated_config.provider == config.provider
    end

    test "re-validates struct fields" do
      %Config{} = base_config = Config.new(model: "gpt-4", provider: :openai, prompt: "test")
      config = %{base_config | max_char_buffer: -1}

      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               Config.validate(config)
    end
  end

  describe "validate!/1" do
    test "returns config for valid options" do
      config =
        Config.validate!(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: 1000)

      assert %Config{} = config
      assert config.max_char_buffer == 1000
    end

    test "raises for invalid max_char_buffer" do
      assert_raise LeXtract.Error.Invalid.Config, ~r/expected positive integer/, fn ->
        Config.validate!(model: "gpt-4", provider: :openai, prompt: "test", max_char_buffer: -1)
      end
    end

    test "raises for invalid temperature" do
      assert_raise LeXtract.Error.Invalid.Config, ~r/must be a float between 0.0 and 1.0/, fn ->
        Config.validate!(model: "gpt-4", provider: :openai, prompt: "test", temperature: 1.5)
      end
    end

    test "raises for invalid format" do
      assert_raise LeXtract.Error.Invalid.Config, ~r/expected one of \[:json, :yaml\]/, fn ->
        Config.validate!(model: "gpt-4", provider: :openai, prompt: "test", format: :csv)
      end
    end

    test "accepts valid struct" do
      config = Config.new(model: "gpt-4", provider: :openai, prompt: "test")

      validated = Config.validate!(config)
      assert validated.model == config.model
    end
  end
end
