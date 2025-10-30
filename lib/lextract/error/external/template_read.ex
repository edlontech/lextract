defmodule LeXtract.Error.External.TemplateRead do
  @moduledoc """
  Error for template file I/O failures.

  Raised when a template file cannot be read from disk, typically
  due to missing files, permission issues, or I/O errors.

  ## Examples

      iex> error = LeXtract.Error.External.TemplateRead.exception(
      ...>   file_path: "/tmp/missing.json",
      ...>   reason: :enoent
      ...> )
      iex> String.contains?(Exception.message(error), "missing.json")
      true

      iex> error = LeXtract.Error.External.TemplateRead.exception(
      ...>   file_path: "/etc/protected.json",
      ...>   reason: :eacces
      ...> )
      iex> String.contains?(Exception.message(error), "permission denied")
      true

  """

  use Splode.Error,
    fields: [:file_path, :reason],
    class: :external

  @type t :: %__MODULE__{
          file_path: String.t(),
          reason: atom() | String.t()
        }

  @doc """
  Formats the error message for template read failures.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{file_path: path, reason: reason}) when is_atom(reason) do
    "Failed to read template file #{path}: #{:file.format_error(reason)}"
  end

  def message(%__MODULE__{file_path: path, reason: reason}) when is_binary(reason) do
    "Failed to read template file #{path}: #{reason}"
  end

  def message(%__MODULE__{file_path: path, reason: reason}) do
    "Failed to read template file #{path}: #{inspect(reason)}"
  end
end
