defmodule CommBus.Conversation do
  @moduledoc "Conversation session state."

  alias CommBus.Message

  @type t :: %__MODULE__{
          id: term(),
          messages: [Message.t()],
          depth: non_neg_integer(),
          metadata: map()
        }

  defstruct id: nil,
            messages: [],
            depth: 0,
            metadata: %{}
end
