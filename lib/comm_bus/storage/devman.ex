defmodule CommBus.Storage.DevMan do
  @moduledoc """
  Storage adapter that persists entries and conversations using DevMan's database.

  Configure in your host application (DevMan) via:

      config :comm_bus, CommBus.Storage.DevMan,
        repo: DevMan.Repo,
        entry_schema: DevMan.Context.Entry,
        conversation_schema: DevMan.Context.Conversation

  ## Migration checklist

  1. Add the configuration above and ensure `DevMan.Repo` is started.
  2. Run `mix comm_bus.entries --store CommBus.Storage.DevMan` to confirm the adapter
     can list existing records.
  3. Use `mix comm_bus.simulate --conversation path/to/sample.yml --store CommBus.Storage.DevMan`
     to dry-run assembly plans against live data.
  4. Attach to `[:comm_bus, :context, :metrics]` telemetry (see `CommBus.Telemetry.metrics/0`)
     to monitor inclusion rates and budget waste before rolling into production.
  """

  @behaviour CommBus.Storage.EntryStore
  @behaviour CommBus.Storage.ConversationStore

  alias CommBus.Storage.EctoAdapter

  @doc "Persists an entry via DevMan's configured Ecto repo and schema."
  @impl true
  def store_entry(entry), do: EctoAdapter.store_entry(entry, config())

  @doc "Lists entries from DevMan's database, applying optional keyword filters."
  @impl true
  def list_entries(opts), do: EctoAdapter.list_entries(opts, config())

  @doc "Fetches a single entry by ID from DevMan's database."
  @impl true
  def get_entry(id), do: EctoAdapter.get_entry(id, config())

  @doc "Deletes an entry by ID from DevMan's database."
  @impl true
  def delete_entry(id), do: EctoAdapter.delete_entry(id, config())

  @doc "Persists a conversation via DevMan's configured Ecto repo."
  @impl true
  def store_conversation(conversation), do: EctoAdapter.store_conversation(conversation, config())

  @doc "Loads a conversation by ID from DevMan's database."
  @impl true
  def load_conversation(id), do: EctoAdapter.load_conversation(id, config())

  @doc "Updates a conversation record in DevMan's database."
  @impl true
  def update_conversation(id, updates), do: EctoAdapter.update_conversation(id, updates, config())

  defp config do
    env_config =
      Application.get_env(:comm_bus, __MODULE__) ||
        raise "Missing config for #{inspect(__MODULE__)}. See module docs for setup instructions."

    Map.new(env_config)
  end
end
