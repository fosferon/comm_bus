defmodule CommBus.Storage.EctoAdapterTest do
  use ExUnit.Case, async: false

  alias CommBus.{Conversation, Entry, Message}
  alias CommBus.Storage.{DevMan, HuMan}

  setup do
    start_supervised!(CommBus.Test.FakeRepo)

    Application.put_env(:comm_bus, CommBus.Storage.Ecto, repo: CommBus.Test.FakeRepo)

    custom_config = [
      repo: CommBus.Test.FakeRepo,
      entry_schema: CommBus.Test.EntrySchema,
      conversation_schema: CommBus.Test.ConversationSchema
    ]

    Application.put_env(:comm_bus, CommBus.Storage.DevMan, custom_config)
    Application.put_env(:comm_bus, CommBus.Storage.HuMan, custom_config)

    on_exit(fn ->
      Application.delete_env(:comm_bus, CommBus.Storage.Ecto)
      Application.delete_env(:comm_bus, CommBus.Storage.DevMan)
      Application.delete_env(:comm_bus, CommBus.Storage.HuMan)
    end)

    :ok
  end

  describe "CommBus.Storage.Ecto" do
    test "stores entries" do
      entry = %Entry{content: "Support context", keywords: ["support"], priority: 1}

      assert {:ok, stored} = CommBus.Storage.Ecto.store_entry(entry)
      assert stored.id

      assert {:ok, [^stored]} = CommBus.Storage.Ecto.list_entries([])
      assert {:ok, ^stored} = CommBus.Storage.Ecto.get_entry(stored.id)
    end

    test "stores conversations" do
      conversation = %Conversation{
        messages: [%Message{role: :user, content: "Hi"}],
        depth: 1
      }

      assert {:ok, stored} = CommBus.Storage.Ecto.store_conversation(conversation)
      assert {:ok, ^stored} = CommBus.Storage.Ecto.load_conversation(stored.id)

      {:ok, updated} = CommBus.Storage.Ecto.update_conversation(stored.id, %{depth: 5})
      assert updated.depth == 5
    end
  end

  describe "custom schema adapters" do
    test "persists entries via DevMan adapter" do
      entry = %Entry{keywords: ["support"], content: "Support context"}

      assert {:ok, stored} = DevMan.store_entry(entry)
      assert stored.id

      assert {:ok, [^stored]} = DevMan.list_entries([])
      assert {:ok, ^stored} = DevMan.get_entry(stored.id)
      assert :ok = DevMan.delete_entry(stored.id)
    end

    test "persists conversations via HuMan adapter" do
      conversation = %Conversation{
        messages: [%Message{role: :user, content: "Hi"}]
      }

      assert {:ok, stored} = HuMan.store_conversation(conversation)
      assert {:ok, ^stored} = HuMan.load_conversation(stored.id)

      {:ok, updated} = HuMan.update_conversation(stored.id, %{depth: 3})
      assert updated.depth == 3
    end
  end
end
