defmodule CommBus.Protocol.LlmCoreAdapterTest do
  use ExUnit.Case, async: false

  alias CommBus.{Conversation, Entry, Message}
  alias CommBus.Protocol.{Context, LlmCoreAdapter, SectionRoles}

  setup do
    SectionRoles.reset()
    :ok
  end

  test "assembles packets with section ordering" do
    conversation = %Conversation{
      messages: [
        %Message{role: :system, content: "Existing"},
        %Message{role: :user, content: "Need auth"},
        %Message{role: :function, content: "data", metadata: %{name: "tool"}}
      ]
    }

    entries = [
      %Entry{
        id: :rules,
        content: "Global rules",
        section: :system,
        mode: :constant,
        token_count: 10
      },
      %Entry{id: :context, content: "Auth context", section: :pre_history, mode: :constant},
      %Entry{id: :post, content: "Post guidance", section: :post_history, mode: :constant}
    ]

    assembly = CommBus.Assembler.assemble_prompt(conversation, entries)

    context = %Context{conversation: conversation, entries: entries, assembly: assembly}

    {:ok, packet} = LlmCoreAdapter.assemble(context)

    assert Enum.map(packet.messages, & &1.role) == [
             :system,
             :system,
             :system,
             :user,
             :tool,
             :system
           ]

    assert Enum.at(packet.messages, 1).metadata.section == :pre_history
    assert Enum.at(packet.messages, -1).metadata.section == :post_history
    assert packet.token_usage == Map.get(assembly, :token_usage)
  end

  test "respects registered section role overrides" do
    :ok = SectionRoles.put(:memory, :assistant)

    conversation = %Conversation{messages: [%Message{role: :user, content: "Need info"}]}

    entries = [
      %Entry{id: :mem, content: "Memory context", section: :memory, mode: :constant}
    ]

    assembly = CommBus.Assembler.assemble_prompt(conversation, entries)
    context = %Context{conversation: conversation, entries: entries, assembly: assembly}

    {:ok, packet} = LlmCoreAdapter.assemble(context)

    assert Enum.map(packet.messages, & &1.role) == [:assistant, :user]
  end
end
