defmodule LeXtract.LLM.ReqLLMTest do
  use ExUnit.Case, async: false
  use Mimic

  alias LeXtract.{ExampleData, LLM, Schema}

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Mimic.copy(ReqLLM)
    :ok
  end

  describe "generate_text/2" do
    test "returns {:ok, text} for a response with list content" do
      ReqLLM
      |> expect(:generate_text, fn "openai:gpt-4o-mini", "prompt", _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: [%{text: "hello"}, %{text: "world"}]},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "openai:gpt-4o-mini",
           id: "test-id"
         }}
      end)

      assert {:ok, "hello\nworld"} =
               LLM.ReqLLM.generate_text("prompt", provider: :openai, model: "gpt-4o-mini")
    end

    test "returns {:ok, text} for a response with binary content" do
      ReqLLM
      |> expect(:generate_text, fn "gemini:gemini-2.0-flash", "prompt", _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "hello world"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "gemini-2.0-flash",
           id: "test-id"
         }}
      end)

      assert {:ok, "hello world"} =
               LLM.ReqLLM.generate_text("prompt",
                 provider: :gemini,
                 model: "gemini-2.0-flash"
               )
    end

    test "passes through {:error, reason} on failure" do
      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, _opts -> {:error, :network_error} end)

      assert {:error, :network_error} =
               LLM.ReqLLM.generate_text("prompt", provider: :openai, model: "gpt-4o-mini")
    end

    test "translates :timeout to :receive_timeout and drops :timeout" do
      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, opts ->
        send(self(), {:captured_opts, opts})

        {:ok,
         %ReqLLM.Response{
           message: %{content: "hi"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "openai:gpt-4o-mini",
           id: "test-id"
         }}
      end)

      assert {:ok, "hi"} =
               LLM.ReqLLM.generate_text("prompt",
                 provider: :openai,
                 model: "gpt-4o-mini",
                 timeout: 90_000
               )

      assert_received {:captured_opts, opts}
      assert Keyword.get(opts, :receive_timeout) == 90_000
      refute Keyword.has_key?(opts, :timeout)
    end

    test "does not clobber an explicitly passed :receive_timeout" do
      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, opts ->
        send(self(), {:captured_opts, opts})

        {:ok,
         %ReqLLM.Response{
           message: %{content: "hi"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "openai:gpt-4o-mini",
           id: "test-id"
         }}
      end)

      assert {:ok, "hi"} =
               LLM.ReqLLM.generate_text("prompt",
                 provider: :openai,
                 model: "gpt-4o-mini",
                 timeout: 90_000,
                 receive_timeout: 30_000
               )

      assert_received {:captured_opts, opts}
      assert Keyword.get(opts, :receive_timeout) == 30_000
      refute Keyword.has_key?(opts, :timeout)
    end

    test "passes api_key through to ReqLLM" do
      ReqLLM
      |> expect(:generate_text, fn _model, _prompt, opts ->
        send(self(), {:captured_opts, opts})

        {:ok,
         %ReqLLM.Response{
           message: %{content: "hi"},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "openai:gpt-4o-mini",
           id: "test-id"
         }}
      end)

      assert {:ok, "hi"} =
               LLM.ReqLLM.generate_text("prompt",
                 provider: :openai,
                 model: "gpt-4o-mini",
                 api_key: "sk-test"
               )

      assert_received {:captured_opts, opts}
      assert Keyword.get(opts, :api_key) == "sk-test"
    end
  end

  describe "generate_object/3" do
    test "returns {:ok, map}" do
      schema = [extractions: [type: {:list, [type: :map]}, default: []]]
      mock_object = %{"extractions" => []}

      ReqLLM
      |> expect(:generate_object, fn "gemini:gemini-2.0-flash", "prompt", _schema, _opts ->
        {:ok,
         %ReqLLM.Response{
           message: %{content: "", role: :assistant},
           object: mock_object,
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "gemini-2.0-flash",
           id: "test-id"
         }}
      end)

      assert {:ok, ^mock_object} =
               LLM.ReqLLM.generate_object("prompt", schema,
                 provider: :gemini,
                 model: "gemini-2.0-flash"
               )
    end

    test "translates :timeout to :receive_timeout and drops :timeout" do
      schema = [extractions: [type: {:list, [type: :map]}, default: []]]

      ReqLLM
      |> expect(:generate_object, fn _model, _prompt, _schema, opts ->
        send(self(), {:captured_opts, opts})

        {:ok,
         %ReqLLM.Response{
           message: %{content: "", role: :assistant},
           object: %{"extractions" => []},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "gemini-2.0-flash",
           id: "test-id"
         }}
      end)

      assert {:ok, _} =
               LLM.ReqLLM.generate_object("prompt", schema,
                 provider: :gemini,
                 model: "gemini-2.0-flash",
                 timeout: 45_000
               )

      assert_received {:captured_opts, opts}
      assert Keyword.get(opts, :receive_timeout) == 45_000
      refute Keyword.has_key?(opts, :timeout)
    end

    test "shapes the schema to strict OpenAI JSON when provider is :openai" do
      examples = [
        %ExampleData{
          input: "Patient takes aspirin",
          output: %{
            "extractions" => [
              %{"class" => "Medication", "medication_attributes" => %{"name" => "aspirin"}}
            ]
          }
        }
      ]

      schema = Schema.from_examples(examples)

      ReqLLM
      |> expect(:generate_object, fn "openai:gpt-4o-mini", "prompt", captured_schema, _opts ->
        send(self(), {:captured_schema, captured_schema})

        {:ok,
         %ReqLLM.Response{
           message: %{content: "", role: :assistant},
           object: %{"extractions" => []},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "gpt-4o-mini",
           id: "test-id"
         }}
      end)

      assert {:ok, _} =
               LLM.ReqLLM.generate_object("prompt", schema,
                 provider: :openai,
                 model: "gpt-4o-mini"
               )

      assert_received {:captured_schema, captured_schema}
      assert captured_schema["additionalProperties"] == false
      assert is_list(captured_schema["required"])
    end

    test "passes api_key through to ReqLLM" do
      schema = [extractions: [type: {:list, [type: :map]}, default: []]]

      ReqLLM
      |> expect(:generate_object, fn _model, _prompt, _schema, opts ->
        send(self(), {:captured_opts, opts})

        {:ok,
         %ReqLLM.Response{
           message: %{content: "", role: :assistant},
           object: %{"extractions" => []},
           finish_reason: :stop,
           usage: %{},
           context: %{},
           model: "gemini-2.0-flash",
           id: "test-id"
         }}
      end)

      assert {:ok, _} =
               LLM.ReqLLM.generate_object("prompt", schema,
                 provider: :gemini,
                 model: "gemini-2.0-flash",
                 api_key: "sk-test"
               )

      assert_received {:captured_opts, opts}
      assert Keyword.get(opts, :api_key) == "sk-test"
    end
  end

  describe "validate_opts/1" do
    test "returns an error when provider is missing" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               LLM.ReqLLM.validate_opts(model: "gpt-4o-mini")
    end

    test "returns an error when model is missing" do
      assert {:error, %LeXtract.Error.Invalid.Config{}} =
               LLM.ReqLLM.validate_opts(provider: :openai)
    end

    test "returns {:ok, opts} when provider and model are present" do
      opts = [provider: :openai, model: "gpt-4o-mini"]
      assert {:ok, ^opts} = LLM.ReqLLM.validate_opts(opts)
    end
  end
end
