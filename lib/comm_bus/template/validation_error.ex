defmodule CommBus.Template.ValidationError do
  @moduledoc false

  @type t :: %__MODULE__{
          path: String.t() | nil,
          field: String.t() | nil,
          message: String.t(),
          line: integer() | nil
        }

  defstruct [:path, :field, :message, :line]

  @doc "Returns the human-readable validation error message string."
  @spec message(t()) :: String.t()
  def message(%__MODULE__{message: msg}), do: msg
end
