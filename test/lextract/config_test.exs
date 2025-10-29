defmodule LeXtract.ConfigTest do
  use ExUnit.Case, async: true
  doctest LeXtract.Config

  alias LeXtract.Config

  describe "default/0" do
    test "returns config with default values" do
      config = Config.default()

      assert config.model_id == "gemini-2.0-flash-exp"
      assert config.api_key == nil
      assert config.max_char_buffer == 1000
      assert config.chunk_overlap == 200
      assert config.temperature == nil
      assert config.format_type == :yaml
      assert config.use_schema_constraints == true
      assert config.batch_size == 10
      assert config.max_workers == 10
      assert config.timeout == 60_000
    end
  end

  describe "new/1" do
    test "creates config with custom values" do
      config = Config.new(model_id: "gpt-4", max_char_buffer: 2000)

      assert config.model_id == "gpt-4"
      assert config.max_char_buffer == 2000
    end

    test "merges with defaults" do
      config = Config.new(model_id: "gpt-4")

      assert config.model_id == "gpt-4"
      assert config.batch_size == 10
      assert config.max_workers == 10
    end

    test "creates config with empty list" do
      config = Config.new()

      assert config.model_id == "gemini-2.0-flash-exp"
    end

    test "sets temperature" do
      config = Config.new(temperature: 0.7)

      assert config.temperature == 0.7
    end

    test "sets format_type" do
      config = Config.new(format_type: :json)

      assert config.format_type == :json
    end

    test "raises for non-positive max_char_buffer" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(max_char_buffer: 0)
      end
    end

    test "raises for negative max_char_buffer" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(max_char_buffer: -1)
      end
    end

    test "raises for temperature below 0.0" do
      assert_raise NimbleOptions.ValidationError, ~r/must be a float between 0.0 and 1.0/, fn ->
        Config.new(temperature: -0.1)
      end
    end

    test "raises for temperature above 1.0" do
      assert_raise NimbleOptions.ValidationError, ~r/must be a float between 0.0 and 1.0/, fn ->
        Config.new(temperature: 1.1)
      end
    end

    test "raises for invalid format_type" do
      assert_raise NimbleOptions.ValidationError, ~r/expected one of \[:json, :yaml\]/, fn ->
        Config.new(format_type: :xml)
      end
    end

    test "raises for non-positive batch_size" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(batch_size: 0)
      end
    end

    test "raises for non-positive max_workers" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.new(max_workers: -5)
      end
    end

    test "raises for invalid timeout" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new(timeout: -100)
      end
    end

    test "accepts :infinity timeout" do
      config = Config.new(timeout: :infinity)

      assert config.timeout == :infinity
    end

    test "raises for unknown keys" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Config.new(unknown_key: "value")
      end
    end
  end

  describe "validate/1 with keyword list" do
    test "returns {:ok, config} for valid options" do
      assert {:ok, config} = Config.validate(max_char_buffer: 1000)

      assert %Config{} = config
      assert config.max_char_buffer == 1000
    end

    test "returns error for non-positive max_char_buffer" do
      assert {:error, %NimbleOptions.ValidationError{key: :max_char_buffer}} =
               Config.validate(max_char_buffer: 0)
    end

    test "returns error for negative max_char_buffer" do
      assert {:error, %NimbleOptions.ValidationError{key: :max_char_buffer}} =
               Config.validate(max_char_buffer: -1)
    end

    test "returns error for temperature below 0.0" do
      assert {:error, %NimbleOptions.ValidationError{key: :temperature}} =
               Config.validate(temperature: -0.1)
    end

    test "returns error for temperature above 1.0" do
      assert {:error, %NimbleOptions.ValidationError{key: :temperature}} =
               Config.validate(temperature: 1.1)
    end

    test "returns error for invalid format_type" do
      assert {:error, %NimbleOptions.ValidationError{key: :format_type}} =
               Config.validate(format_type: :xml)
    end

    test "accepts temperature of 0.0" do
      assert {:ok, config} = Config.validate(temperature: 0.0)

      assert config.temperature == 0.0
    end

    test "accepts temperature of 1.0" do
      assert {:ok, config} = Config.validate(temperature: 1.0)

      assert config.temperature == 1.0
    end

    test "accepts nil temperature" do
      assert {:ok, config} = Config.validate(temperature: nil)

      assert config.temperature == nil
    end

    test "validates all fields together" do
      assert {:ok, config} =
               Config.validate(
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
      config = Config.default()

      assert {:ok, validated_config} = Config.validate(config)
      assert validated_config == config
    end

    test "re-validates struct fields" do
      config = %Config{Config.default() | max_char_buffer: -1}

      assert {:error, %NimbleOptions.ValidationError{key: :max_char_buffer}} =
               Config.validate(config)
    end
  end

  describe "validate!/1" do
    test "returns config for valid options" do
      config = Config.validate!(max_char_buffer: 1000)

      assert %Config{} = config
      assert config.max_char_buffer == 1000
    end

    test "raises for invalid max_char_buffer" do
      assert_raise NimbleOptions.ValidationError, ~r/expected positive integer/, fn ->
        Config.validate!(max_char_buffer: -1)
      end
    end

    test "raises for invalid temperature" do
      assert_raise NimbleOptions.ValidationError, ~r/must be a float between 0.0 and 1.0/, fn ->
        Config.validate!(temperature: 1.5)
      end
    end

    test "raises for invalid format_type" do
      assert_raise NimbleOptions.ValidationError, ~r/expected one of \[:json, :yaml\]/, fn ->
        Config.validate!(format_type: :csv)
      end
    end

    test "accepts valid struct" do
      config = Config.default()

      assert ^config = Config.validate!(config)
    end
  end
end
