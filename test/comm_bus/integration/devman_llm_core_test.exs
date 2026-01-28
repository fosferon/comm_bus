defmodule CommBus.Integration.DevManLlmCoreTest do
  use ExUnit.Case, async: false

  alias CommBus.{Conversation, Entry, Message}
  alias CommBus.Protocol.Pipeline
  alias CommBus.Storage.DevMan

  setup do
    start_supervised!(CommBus.Test.FakeRepo)

    config = [
      repo: CommBus.Test.FakeRepo,
      entry_schema: CommBus.Test.EntrySchema,
      conversation_schema: CommBus.Test.ConversationSchema
    ]

    Application.put_env(:comm_bus, CommBus.Storage.DevMan, config)

    on_exit(fn ->
      Application.delete_env(:comm_bus, CommBus.Storage.DevMan)
    end)

    :ok
  end

  test "DevMan-backed entries flow through the pipeline into llm_core packets" do
    constant = %Entry{
      id: "devman-system",
      content: "DevMan defaults",
      mode: :constant,
      section: :system,
      priority: 100,
      weight: 50
    }

    triggered = %Entry{
      id: "deploy-runbook",
      content: "Deploy runbook snippet",
      keywords: ["deploy"],
      mode: :triggered,
      section: :pre_history,
      priority: 80,
      weight: 40
    }

    assert {:ok, _} = DevMan.store_entry(constant)
    assert {:ok, _} = DevMan.store_entry(triggered)

    conversation = %Conversation{
      messages: [
        %Message{role: :user, content: "Need deploy guidance"}
      ],
      metadata: %{tool: :devman}
    }

    {:ok, stored_conversation} = DevMan.store_conversation(conversation)
    {:ok, loaded_conversation} = DevMan.load_conversation(stored_conversation.id)

    {:ok, entries} = DevMan.list_entries([])

    assert {:ok, packet} = Pipeline.run({loaded_conversation, entries})

    assert Enum.any?(Map.get(packet.sections, :system, []), &(&1.content == "DevMan defaults"))

    assert Enum.any?(
             Map.get(packet.sections, :pre_history, []),
             &(&1.content == "Deploy runbook snippet")
           )

    assert [%Message{role: :user, content: "Need deploy guidance"}] =
             Enum.take(Map.get(packet.sections, :history, []), 1)

    assert Enum.any?(packet.messages, fn %{role: role, content: content} ->
             role == :system and content =~ "DevMan"
           end)

    assert %{
             adapter: CommBus.Protocol.LlmCoreAdapter,
             section_roles: section_roles
           } = packet.metadata

    assert section_roles[:system] == :system
  end
end
