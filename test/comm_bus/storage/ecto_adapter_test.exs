defmodule CommBus.Storage.EctoAdapterTest do
  use ExUnit.Case, async: false

  alias CommBus.{Conversation, Entry, Message}
  alias CommBus.Storage.EctoAdapter

  setup do
    start_supervised!(CommBus.Test.FakeRepo)

    custom_config = %{
      repo: CommBus.Test.FakeRepo,
      entry_schema: CommBus.Test.EntrySchema,
      conversation_schema: CommBus.Test.ConversationSchema
    }

    on_exit(fn ->
      Application.delete_env(:comm_bus, CommBus.Storage.Ecto)
    end)

    %{config: custom_config}
  end

  describe "EctoAdapter direct usage" do
    test "stores entries via config map", %{config: config} do
      entry = %Entry{content: "Support context", keywords: ["support"], priority: 1}

      assert {:ok, stored} = EctoAdapter.store_entry(entry, config)
      assert stored.id

      assert {:ok, [^stored]} = EctoAdapter.list_entries([], config)
      assert {:ok, ^stored} = EctoAdapter.get_entry(stored.id, config)
    end

    test "stores conversations via config map", %{config: config} do
      conversation = %Conversation{
        messages: [%Message{role: :user, content: "Hi"}],
        depth: 1
      }

      assert {:ok, stored} = EctoAdapter.store_conversation(conversation, config)
      assert {:ok, ^stored} = EctoAdapter.load_conversation(stored.id, config)

      {:ok, updated} = EctoAdapter.update_conversation(stored.id, %{depth: 5}, config)
      assert updated.depth == 5
    end

    test "deletes entries via config map", %{config: config} do
      entry = %Entry{keywords: ["support"], content: "Support context"}

      assert {:ok, stored} = EctoAdapter.store_entry(entry, config)
      assert :ok = EctoAdapter.delete_entry(stored.id, config)
      assert {:error, :not_found} = EctoAdapter.get_entry(stored.id, config)
    end
  end

  describe "EctoAdapter via Application config (CommBus.Storage.Ecto)" do
    setup do
      Application.put_env(:comm_bus, CommBus.Storage.Ecto, repo: CommBus.Test.FakeRepo)
      :ok
    end

    test "stores entries using module config" do
      entry = %Entry{content: "Module config entry", keywords: ["test"], priority: 1}

      assert {:ok, stored} = CommBus.Storage.Ecto.store_entry(entry)
      assert {:ok, [^stored]} = CommBus.Storage.Ecto.list_entries([])
    end
  end
end
