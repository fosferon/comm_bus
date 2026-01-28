defmodule CommBus.Message do
  @moduledoc "Conversation message."

  @type role :: :system | :user | :assistant | :tool | :function

  @type t :: %__MODULE__{
          role: role(),
          content: String.t(),
          token_count: non_neg_integer() | nil,
          metadata: map()
        }

  defstruct role: :user,
            content: "",
            token_count: nil,
            metadata: %{}
end
