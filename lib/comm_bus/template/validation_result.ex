defmodule CommBus.Template.ValidationResult do
  @moduledoc false

  @type t :: %__MODULE__{
          valid: boolean(),
          warnings: [String.t()],
          variables_required: [String.t()],
          partials_required: [String.t()]
        }

  defstruct valid: true, warnings: [], variables_required: [], partials_required: []
end
