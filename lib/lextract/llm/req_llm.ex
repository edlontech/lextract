defmodule LeXtract.LLM.ReqLLM do
  @moduledoc """
  Default `LeXtract.LLM` adapter, backed by the `req_llm` library.

  Builds the `"provider:model"` model string from `opts[:provider]` and
  `opts[:model]`, unwraps `%ReqLLM.Response{}` into plain text or maps, and
  applies OpenAI's strict JSON schema shaping when `opts[:provider] == :openai`.
  Translates the legacy `opts[:timeout]` key to ReqLLM's `:receive_timeout`
  (without clobbering an explicitly passed `:receive_timeout`).

  This adapter makes exactly one `ReqLLM` call per invocation; concurrency
  is owned by `LeXtract.Annotator`.
  """

  @behaviour LeXtract.LLM

  require Logger

  @adapter_opt_keys [:model, :max_concurrency, :provider]

  @impl LeXtract.LLM
  def generate_text(prompt, opts) do
    model = build_model(opts)
    llm_opts = build_llm_opts(opts)

    case ReqLLM.generate_text(model, prompt, llm_opts) do
      {:ok, response} -> {:ok, extract_response_text(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl LeXtract.LLM
  def generate_object(prompt, schema, opts) do
    model = build_model(opts)
    llm_opts = build_llm_opts(opts)
    final_schema = shape_schema(schema, Keyword.get(opts, :provider))

    case ReqLLM.generate_object(model, prompt, final_schema, llm_opts) do
      {:ok, response} -> {:ok, extract_response_object(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl LeXtract.LLM
  def validate_opts(opts) do
    cond do
      not Code.ensure_loaded?(ReqLLM) ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors: "req_llm not available; add it to deps or configure a different :llm adapter"
         )}

      is_nil(Keyword.get(opts, :provider)) or is_nil(Keyword.get(opts, :model)) ->
        {:error,
         LeXtract.Error.Invalid.Config.exception(
           errors: "provider and model are required for LeXtract.LLM.ReqLLM"
         )}

      true ->
        {:ok, opts}
    end
  end

  defp build_model(opts) do
    provider = Keyword.fetch!(opts, :provider)
    model = Keyword.fetch!(opts, :model)
    "#{provider}:#{model}"
  end

  defp build_llm_opts(opts) do
    opts
    |> Keyword.drop(@adapter_opt_keys)
    |> translate_timeout()
  end

  defp translate_timeout(opts) do
    case Keyword.pop(opts, :timeout) do
      {nil, opts} -> opts
      {timeout, opts} -> Keyword.put_new(opts, :receive_timeout, timeout)
    end
  end

  defp shape_schema(schema, :openai), do: build_openai_strict_json_schema(schema)
  defp shape_schema(schema, _provider), do: schema

  defp build_openai_strict_json_schema(schema) when is_list(schema) do
    extractions_spec = Keyword.get(schema, :extractions, [])
    keys = Keyword.get(extractions_spec, :keys, [])

    properties =
      Enum.into(keys, %{}, fn {key, opts} ->
        {to_string(key), build_property_schema(opts)}
      end)

    required_keys = Map.keys(properties)

    items_schema = %{
      "type" => "object",
      "properties" => properties,
      "required" => required_keys,
      "additionalProperties" => false
    }

    %{
      "type" => "object",
      "properties" => %{
        "extractions" => %{
          "type" => "array",
          "items" => items_schema,
          "description" => Keyword.get(extractions_spec, :doc, "List of extracted entities")
        }
      },
      "required" => ["extractions"],
      "additionalProperties" => false
    }
  end

  defp build_property_schema(opts) do
    base =
      case Keyword.get(opts, :type, :string) do
        :string ->
          %{"type" => "string"}

        :integer ->
          %{"type" => "integer"}

        :map ->
          %{
            "type" => "object",
            "properties" => %{},
            "required" => [],
            "additionalProperties" => false
          }

        _ ->
          %{"type" => "string"}
      end

    case Keyword.get(opts, :doc) do
      nil -> base
      doc -> Map.put(base, "description", doc)
    end
  end

  defp extract_response_text(%ReqLLM.Response{message: %{content: content}})
       when is_list(content) do
    content
    |> Enum.filter(fn part -> is_map(part) and Map.has_key?(part, :text) end)
    |> Enum.map_join("\n", fn part -> part.text end)
  end

  defp extract_response_text(%ReqLLM.Response{message: %{content: content}})
       when is_binary(content) do
    content
  end

  defp extract_response_text(%ReqLLM.Response{} = response) do
    Logger.warning("Unexpected ReqLLM response format: #{inspect(response)}")
    ""
  end

  defp extract_response_text(response) do
    Logger.warning("Unexpected response type: #{inspect(response)}")
    ""
  end

  defp extract_response_object(%ReqLLM.Response{object: object}) when is_map(object) do
    object
  end

  defp extract_response_object(%ReqLLM.Response{} = response) do
    Logger.warning("Unexpected ReqLLM response format for object: #{inspect(response)}")
    %{"extractions" => []}
  end

  defp extract_response_object(response) do
    Logger.warning("Unexpected response type for object: #{inspect(response)}")
    %{"extractions" => []}
  end
end
