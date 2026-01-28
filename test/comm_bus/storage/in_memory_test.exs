defmodule CommBus.Storage.InMemoryTest do
  use ExUnit.Case, async: true

  alias CommBus.{Conversation, Entry, Message}
  alias CommBus.Storage.InMemory

  setup do
    suffix = System.unique_integer()
    entries_table = String.to_atom("comm_bus_entries_" <> Integer.to_string(suffix))
    conversations_table = String.to_atom("comm_bus_conversations_" <> Integer.to_string(suffix))

    Application.put_env(:comm_bus, :entries_table, entries_table)
    Application.put_env(:comm_bus, :conversations_table, conversations_table)

    :ok
  end

  test "stores and retrieves entries" do
    entry = %Entry{id: 1, keywords: ["billing"], content: "Billing context"}

    assert {:ok, ^entry} = InMemory.store_entry(entry)
    assert {:ok, [%Entry{} = stored]} = InMemory.list_entries([])
    assert stored.content == "Billing context"
    assert {:ok, ^stored} = InMemory.get_entry(1)

    assert :ok = InMemory.delete_entry(1)
    assert {:error, :not_found} = InMemory.get_entry(1)
  end

  test "filters entries by keyword and enabled flag" do
    entry_a = %Entry{id: :a, keywords: ["auth"], enabled: true}
    entry_b = %Entry{id: :b, keywords: ["billing"], enabled: false}

    InMemory.store_entry(entry_a)
    InMemory.store_entry(entry_b)

    assert {:ok, [^entry_a]} = InMemory.list_entries(keywords: ["auth"], enabled: true)
    assert {:ok, [^entry_b]} = InMemory.list_entries(enabled: false)
  end

  test "stores and updates conversations" do
    conversation = %Conversation{
      id: 10,
      messages: [%Message{role: :user, content: "Hi"}],
      metadata: %{channel: "cli"}
    }

    assert {:ok, ^conversation} = InMemory.store_conversation(conversation)
    assert {:ok, ^conversation} = InMemory.load_conversation(10)

    {:ok, updated} = InMemory.update_conversation(10, %{depth: 2})
    assert updated.depth == 2
  end
end
