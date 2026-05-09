defmodule CommBus.Integration.PipelineTest do
  use ExUnit.Case, async: false

  alias CommBus.{Conversation, Entry, Message}
  alias CommBus.Protocol.Pipeline
  alias CommBus.Storage.EctoAdapter

  setup do
    start_supervised!(CommBus.Test.FakeRepo)

    config = %{
      repo: CommBus.Test.FakeRepo,
      entry_schema: CommBus.Test.EntrySchema,
      conversation_schema: CommBus.Test.ConversationSchema
    }

    %{config: config}
  end

  test "EctoAdapter-backed entries flow through the pipeline into packets", %{config: config} do
    constant = %Entry{
      id: "system-defaults",
      content: "System defaults",
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

    assert {:ok, _} = EctoAdapter.store_entry(constant, config)
    assert {:ok, _} = EctoAdapter.store_entry(triggered, config)

    conversation = %Conversation{
      messages: [
        %Message{role: :user, content: "Need deploy guidance"}
      ]
    }

    {:ok, stored_conversation} = EctoAdapter.store_conversation(conversation, config)
    {:ok, loaded_conversation} = EctoAdapter.load_conversation(stored_conversation.id, config)

    {:ok, entries} = EctoAdapter.list_entries([], config)

    assert {:ok, packet} = Pipeline.run({loaded_conversation, entries})

    assert Enum.any?(Map.get(packet.sections, :system, []), &(&1.content == "System defaults"))

    assert Enum.any?(
             Map.get(packet.sections, :pre_history, []),
             &(&1.content == "Deploy runbook snippet")
           )

    assert [%Message{role: :user, content: "Need deploy guidance"}] =
             Enum.take(Map.get(packet.sections, :history, []), 1)
  end
end
