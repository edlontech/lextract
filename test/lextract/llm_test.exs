defmodule LeXtract.LLMTest do
  use ExUnit.Case, async: true

  defmodule FakeAdapter do
    @behaviour LeXtract.LLM

    @impl LeXtract.LLM
    def generate_text(_prompt, _opts), do: {:ok, "text"}

    @impl LeXtract.LLM
    def generate_object(_prompt, _schema, _opts), do: {:ok, %{}}

    @impl LeXtract.LLM
    def validate_opts(opts), do: {:ok, opts}
  end

  test "defines the required callbacks" do
    callbacks = LeXtract.LLM.behaviour_info(:callbacks)

    assert {:generate_text, 2} in callbacks
    assert {:generate_object, 3} in callbacks
    assert {:validate_opts, 1} in callbacks
  end

  test "validate_opts/1 is optional" do
    assert {:validate_opts, 1} in LeXtract.LLM.behaviour_info(:optional_callbacks)
  end

  test "a module implementing the behaviour satisfies the contract" do
    assert Code.ensure_loaded?(FakeAdapter)
    assert function_exported?(FakeAdapter, :generate_text, 2)
    assert function_exported?(FakeAdapter, :generate_object, 3)
    assert function_exported?(FakeAdapter, :validate_opts, 1)

    assert {:ok, "text"} = FakeAdapter.generate_text("prompt", [])
    assert {:ok, %{}} = FakeAdapter.generate_object("prompt", [], [])
    assert {:ok, []} = FakeAdapter.validate_opts([])
  end
end
