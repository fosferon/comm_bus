defmodule CommBus.Protocol.Context do
  @moduledoc """
  Execution context shared across CommBus protocol adapters.
  """

  alias CommBus.{Conversation, Entry}

  @type t :: %__MODULE__{
          conversation: Conversation.t(),
          entries: [Entry.t()],
          opts: keyword(),
          assembly: map() | nil
        }

  @enforce_keys [:conversation, :entries]
  defstruct conversation: %Conversation{},
            entries: [],
            opts: [],
            assembly: nil

  @doc "Attach the assembled prompt payload produced by CommBus.Assembler."
  @spec put_assembly(t(), map()) :: t()
  def put_assembly(%__MODULE__{} = context, assembly) do
    %{context | assembly: assembly}
  end
end
