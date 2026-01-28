defmodule CommBus.Template.ValidationError do
  @moduledoc false

  @type t :: %__MODULE__{
          path: String.t() | nil,
          field: String.t() | nil,
          message: String.t(),
          line: integer() | nil
        }

  defstruct [:path, :field, :message, :line]

  def message(%__MODULE__{message: msg}), do: msg
end
