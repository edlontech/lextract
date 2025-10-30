defmodule LeXtract.ExampleData do
  @moduledoc """
  Represents a training example for extraction with input text and expected output.

  Used to provide few-shot examples to LLMs and for schema generation from examples.

  ## Fields

  * `:input` - The input text to extract from
  * `:output` - The expected output structure with extractions

  ## Examples

      iex> example = %LeXtract.ExampleData{
      ...>   input: "Patient takes aspirin 100mg daily",
      ...>   output: %{
      ...>     "extractions" => [
      ...>       %{
      ...>         "class" => "Medication",
      ...>         "medication_attributes" => %{
      ...>           "name" => "aspirin",
      ...>           "dosage" => "100mg"
      ...>         }
      ...>       }
      ...>     ]
      ...>   }
      ...> }
      iex> example.input
      "Patient takes aspirin 100mg daily"

  """

  @type t :: %__MODULE__{
          input: String.t(),
          output: map()
        }

  @enforce_keys [:input, :output]
  defstruct [:input, :output]

  @doc """
  Creates a new example data struct.

  ## Examples

      iex> example = LeXtract.ExampleData.new("text", %{"extractions" => []})
      iex> example.input
      "text"

  """
  @spec new(String.t(), map()) :: t()
  def new(input, output) when is_binary(input) and is_map(output) do
    %__MODULE__{
      input: input,
      output: output
    }
  end
end
