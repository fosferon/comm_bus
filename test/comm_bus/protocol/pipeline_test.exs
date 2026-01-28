defmodule CommBus.Protocol.PipelineTest do
  use ExUnit.Case

  alias CommBus.{Conversation, Entry, Message}
  alias CommBus.Protocol.{Context, Packet, Pipeline}

  defmodule FailingAdapter do
    @behaviour CommBus.Protocol.Adapter

    @impl true
    def assemble(_context), do: {:error, :forced_failure}
  end

  defmodule InvalidAdapter do
    @behaviour CommBus.Protocol.Adapter

    @impl true
    def assemble(_context) do
      packet = %Packet{messages: [], sections: %{}, token_usage: %{}}
      {:ok, packet}
    end
  end

  test "pipeline assembles conversation into packet" do
    conversation = %Conversation{
      id: 42,
      messages: [%Message{role: :user, content: "Need help"}]
    }

    entries = [
      %Entry{id: :rules, content: "Rules", section: :system, mode: :constant}
    ]

    assert {:ok, %Packet{} = packet} = Pipeline.run({conversation, entries})
    assert length(packet.messages) == 2
    assert packet.conversation.id == 42
  end

  test "pipeline propagates adapter errors" do
    conversation = %Conversation{messages: [%Message{role: :user, content: "foo"}]}
    entries = []

    assert {:error, :forced_failure} =
             Pipeline.run(%Context{conversation: conversation, entries: entries},
               adapter: FailingAdapter
             )
  end

  test "pipeline validates packets" do
    conversation = %Conversation{messages: [%Message{role: :user, content: "foo"}]}
    entries = []

    assert {:error, :empty_packet_messages} =
             Pipeline.run(%Context{conversation: conversation, entries: entries},
               adapter: InvalidAdapter
             )
  end
end
