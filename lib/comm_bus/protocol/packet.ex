defmodule CommBus.Protocol.Packet do
  @moduledoc """
  Canonical payload produced by CommBus protocol adapters.
  """

  alias CommBus.{Conversation, Entry, Message}

  @type message_role :: Message.role() | :tool

  @type message :: %{
          role: message_role() | String.t(),
          content: String.t(),
          metadata: map()
        }

  @type t :: %__MODULE__{
          conversation: Conversation.t() | nil,
          messages: [message()],
          sections: map(),
          included_entries: [Entry.t()],
          excluded_entries: [Entry.t()],
          token_usage: map(),
          metadata: map()
        }

  @enforce_keys [:messages]
  defstruct conversation: nil,
            messages: [],
            sections: %{},
            included_entries: [],
            excluded_entries: [],
            token_usage: %{},
            metadata: %{}
end
