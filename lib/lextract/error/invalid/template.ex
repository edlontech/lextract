defmodule LeXtract.Error.Invalid.Template do
  @moduledoc """
  Error for invalid template structure or content.

  Raised when template data is malformed, missing required fields,
  or has invalid structure.

  ## Examples

      iex> error = LeXtract.Error.Invalid.Template.exception(
      ...>   reason: "Template must have a non-empty description"
      ...> )
      iex> Exception.message(error)
      "Invalid template: Template must have a non-empty description"

      iex> error = LeXtract.Error.Invalid.Template.exception(
      ...>   reason: "Examples must be a list",
      ...>   template_path: "/tmp/template.json"
      ...> )
      iex> String.contains?(Exception.message(error), "/tmp/template.json")
      true

  """

  use Splode.Error,
    fields: [:reason, :template_path],
    class: :invalid

  @type t :: %__MODULE__{
          reason: String.t(),
          template_path: String.t() | nil
        }

  @doc """
  Formats the error message for template validation errors.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{reason: reason, template_path: nil}) do
    "Invalid template: #{reason}"
  end

  def message(%__MODULE__{reason: reason, template_path: path}) do
    "Invalid template at #{path}: #{reason}"
  end
end
