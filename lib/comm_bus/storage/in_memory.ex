defmodule CommBus.Storage.InMemory do
  @moduledoc """
  Lightweight ETS-backed storage adapter implementing both CommBus storage behaviours.

  This adapter is useful for tests, prototyping, and consumers that do not yet have
  a database wired up. Tables are created on demand and names can be customized via
  the `:entries_table` and `:conversations_table` application env keys.
  """

  @behaviour CommBus.Storage.EntryStore
  @behaviour CommBus.Storage.ConversationStore

  alias CommBus.{Conversation, Entry}

  @entries_table :comm_bus_entries
  @conversations_table :comm_bus_conversations

  @doc """
  Stores an entry in the ETS table, auto-generating an ID if not present.

  ## Parameters

    - `entry` — A `%CommBus.Entry{}` struct.

  ## Returns

  `{:ok, %CommBus.Entry{}}` with the (possibly auto-generated) ID.
  """
  @impl true
  def store_entry(%Entry{} = entry) do
    ensure_tables()
    entry = ensure_entry_id(entry)
    :ets.insert(entries_table(), {entry.id, entry})
    {:ok, entry}
  end

  @doc """
  Lists all entries from the ETS table, applying optional keyword filters
  for `:enabled`, `:mode`, and `:keywords`.

  ## Parameters

    - `opts` — Keyword filters.

  ## Returns

  `{:ok, [%CommBus.Entry{}]}`.
  """
  @impl true
  def list_entries(opts) when is_list(opts) do
    ensure_tables()

    entries_table()
    |> :ets.tab2list()
    |> Enum.map(fn {_id, entry} -> entry end)
    |> apply_entry_filters(opts)
    |> then(&{:ok, &1})
  end

  @doc """
  Looks up a single entry by ID in the ETS table.

  ## Parameters

    - `id` — The entry identifier.

  ## Returns

  `{:ok, %CommBus.Entry{}}` if found, or `{:error, :not_found}`.
  """
  @impl true
  def get_entry(id) do
    ensure_tables()

    case :ets.lookup(entries_table(), id) do
      [{^id, entry}] -> {:ok, entry}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Removes an entry from the ETS table by ID.

  ## Parameters

    - `id` — The entry identifier.

  ## Returns

  `:ok`.
  """
  @impl true
  def delete_entry(id) do
    ensure_tables()
    true = :ets.delete(entries_table(), id)
    :ok
  end

  @doc """
  Stores a conversation in the ETS table, auto-generating an ID if not present.

  ## Parameters

    - `conversation` — A `%CommBus.Conversation{}` struct.

  ## Returns

  `{:ok, %CommBus.Conversation{}}` with the (possibly auto-generated) ID.
  """
  @impl true
  def store_conversation(%Conversation{} = conversation) do
    ensure_tables()
    conversation = ensure_conversation_id(conversation)
    :ets.insert(conversations_table(), {conversation.id, conversation})
    {:ok, conversation}
  end

  @doc """
  Looks up a conversation by ID in the ETS table.

  ## Parameters

    - `id` — The conversation identifier.

  ## Returns

  `{:ok, %CommBus.Conversation{}}` if found, or `{:error, :not_found}`.
  """
  @impl true
  def load_conversation(id) do
    ensure_tables()

    case :ets.lookup(conversations_table(), id) do
      [{^id, conversation}] -> {:ok, conversation}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Updates an existing conversation in the ETS table, merging the given updates
  into the existing struct.

  ## Parameters

    - `id` — The conversation identifier.
    - `updates` — A map of fields to update.

  ## Returns

  `{:ok, %CommBus.Conversation{}}` on success, or `{:error, :not_found}`.
  """
  @impl true
  def update_conversation(id, updates) when is_map(updates) do
    ensure_tables()

    with {:ok, conversation} <- load_conversation(id) do
      updated = struct(conversation, updates)
      :ets.insert(conversations_table(), {id, updated})
      {:ok, updated}
    end
  end

  defp ensure_entry_id(%Entry{id: nil} = entry) do
    %{entry | id: {:entry, System.unique_integer([:positive])}}
  end

  defp ensure_entry_id(entry), do: entry

  defp ensure_conversation_id(%Conversation{id: nil} = conversation) do
    %{conversation | id: {:conversation, System.unique_integer([:positive])}}
  end

  defp ensure_conversation_id(conversation), do: conversation

  defp apply_entry_filters(entries, opts) do
    entries
    |> filter_if(opts[:enabled], fn entry, enabled -> entry.enabled == enabled end)
    |> filter_if(opts[:mode], fn entry, mode -> entry.mode == mode end)
    |> filter_keywords(opts[:keywords])
  end

  defp filter_if(entries, nil, _fun), do: entries

  defp filter_if(entries, value, fun) do
    Enum.filter(entries, &fun.(&1, value))
  end

  defp filter_keywords(entries, nil), do: entries

  defp filter_keywords(entries, keywords) when is_list(keywords) do
    Enum.filter(entries, fn entry -> Enum.any?(entry.keywords, &(&1 in keywords)) end)
  end

  defp ensure_tables do
    create_table(entries_table())
    create_table(conversations_table())
    :ok
  end

  defp create_table(name) do
    case :ets.whereis(name) do
      :undefined -> :ets.new(name, [:set, :public, :named_table, read_concurrency: true])
      _ -> :ok
    end
  end

  defp entries_table do
    Application.get_env(:comm_bus, :entries_table, @entries_table)
  end

  defp conversations_table do
    Application.get_env(:comm_bus, :conversations_table, @conversations_table)
  end
end
