defmodule LeXtract.Schema do
  @moduledoc """
  Generate and manage NimbleOptions schemas from extraction examples.

  Provides schema generation for structured output with ReqLLM's generate_object/4.

  ## Example

      iex> examples = [
      ...>   %LeXtract.ExampleData{
      ...>     input: "Patient takes aspirin",
      ...>     output: %{
      ...>       "extractions" => [
      ...>         %{"class" => "Medication", "medication_attributes" => %{"name" => "aspirin"}}
      ...>       ]
      ...>     }
      ...>   }
      ...> ]
      iex> schema = LeXtract.Schema.from_examples(examples)
      iex> is_list(schema)
      true
      iex> Keyword.has_key?(schema, :extractions)
      true

  """

  require Logger

  alias LeXtract.ExampleData
  alias LeXtract.Schema.Analyzer

  @doc """
  Generates NimbleOptions schema from example extractions.

  Analyzes the provided examples to automatically infer a schema suitable for
  use with ReqLLM's generate_object/4. The schema will include all extraction
  classes and their attributes found in the examples.

  ## Parameters

    * `examples` - List of LeXtract.ExampleData structs
    * `opts` - Options (see below)

  ## Options

    * `:attribute_suffix` - Suffix for attribute fields (default: "_attributes")
    * `:required` - List of required field names (default: [])
    * `:manual_schema` - User-provided schema to merge with generated (default: nil)

  ## Examples

      iex> examples = [
      ...>   %LeXtract.ExampleData{
      ...>     input: "Dr. Smith prescribed aspirin to John Doe",
      ...>     output: %{
      ...>       "extractions" => [
      ...>         %{
      ...>           "class" => "Person",
      ...>           "person_attributes" => %{"name" => "Dr. Smith", "role" => "doctor"}
      ...>         },
      ...>         %{
      ...>           "class" => "Medication",
      ...>           "medication_attributes" => %{"name" => "aspirin"}
      ...>         }
      ...>       ]
      ...>     }
      ...>   }
      ...> ]
      iex> schema = LeXtract.Schema.from_examples(examples)
      iex> Keyword.has_key?(schema, :extractions)
      true

  """
  @spec from_examples([ExampleData.t()], keyword()) :: keyword()
  def from_examples(examples, opts \\ []) when is_list(examples) do
    schema_info = Analyzer.analyze(examples)
    generated_schema = Analyzer.to_nimble_options(schema_info)

    case Keyword.get(opts, :manual_schema) do
      nil ->
        generated_schema

      manual_schema when is_list(manual_schema) ->
        merge(generated_schema, manual_schema)
    end
  end

  @doc """
  Validates extraction data against a schema.

  Uses NimbleOptions.validate/2 internally to validate the provided data
  against the schema.

  ## Parameters

    * `data` - Data to validate (typically a keyword list or map)
    * `schema` - NimbleOptions schema (keyword list)

  ## Returns

  `:ok` if valid, `{:error, reason}` otherwise.

  ## Examples

      iex> schema = [
      ...>   extractions: [
      ...>     type: {:list, :map},
      ...>     default: []
      ...>   ]
      ...> ]
      iex> data = [extractions: []]
      iex> LeXtract.Schema.validate(data, schema)
      {:ok, [extractions: []]}

      iex> schema = [
      ...>   extractions: [
      ...>     type: {:list, :map},
      ...>     required: true
      ...>   ]
      ...> ]
      iex> data = []
      iex> {:error, %NimbleOptions.ValidationError{}} = LeXtract.Schema.validate(data, schema)

  """
  @spec validate(term(), keyword()) :: {:ok, term()} | {:error, term()}
  def validate(data, schema) when is_list(schema) do
    NimbleOptions.validate(data, schema)
  end

  @doc """
  Merges user-provided schema with generated schema.

  User schema takes precedence for conflicts. This allows users to override
  specific parts of the automatically generated schema while keeping the rest.

  ## Parameters

    * `generated_schema` - Schema generated from examples
    * `user_schema` - User-provided schema overrides

  ## Returns

  Merged schema as keyword list.

  ## Examples

      iex> generated = [
      ...>   extractions: [type: {:list, [type: :map]}, default: []]
      ...> ]
      iex> user = [
      ...>   extractions: [type: {:list, [type: :map]}, default: [], required: true]
      ...> ]
      iex> merged = LeXtract.Schema.merge(generated, user)
      iex> merged[:extractions][:required]
      true

      iex> generated = [
      ...>   name: [type: :string],
      ...>   age: [type: :integer]
      ...> ]
      iex> user = [
      ...>   age: [type: :integer, required: true]
      ...> ]
      iex> merged = LeXtract.Schema.merge(generated, user)
      iex> Keyword.has_key?(merged, :name)
      true
      iex> merged[:age][:required]
      true

  """
  @spec merge(keyword(), keyword()) :: keyword()
  def merge(generated_schema, user_schema)
      when is_list(generated_schema) and is_list(user_schema) do
    generated_schema
    |> Enum.map(fn {key, generated_opts} ->
      case Keyword.get(user_schema, key) do
        nil ->
          {key, generated_opts}

        user_opts when is_list(user_opts) and is_list(generated_opts) ->
          merged_opts = merge_option_specs(generated_opts, user_opts)
          {key, merged_opts}

        user_opts when is_list(user_opts) ->
          {key, user_opts}

        _invalid_user_opts ->
          Logger.warning(
            "Invalid format for key `#{inspect(key)}` in user schema. " <>
              "Expected keyword list. Using generated value."
          )

          {key, generated_opts}
      end
    end)
    |> Keyword.merge(
      Enum.filter(user_schema, fn {key, _} ->
        key not in Keyword.keys(generated_schema)
      end)
    )
  end

  defp merge_option_specs(generated_opts, user_opts) do
    Keyword.merge(generated_opts, user_opts, fn
      :keys, gen_keys, user_keys when is_list(gen_keys) and is_list(user_keys) ->
        merge_keys(gen_keys, user_keys)

      _key, _gen_val, user_val ->
        user_val
    end)
  end

  defp merge_keys(gen_keys, user_keys) do
    gen_key_names = Keyword.keys(gen_keys)

    gen_keys
    |> Enum.map(fn {key, gen_opts} ->
      case Keyword.get(user_keys, key) do
        nil ->
          {key, gen_opts}

        user_opts when is_list(user_opts) and is_list(gen_opts) ->
          {key, Keyword.merge(gen_opts, user_opts)}

        user_opts ->
          {key, user_opts}
      end
    end)
    |> Keyword.merge(
      Enum.filter(user_keys, fn {key, _} ->
        key not in gen_key_names
      end)
    )
  end
end
