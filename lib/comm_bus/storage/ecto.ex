defmodule CommBus.Storage.Ecto do
  @moduledoc """
  Default Ecto-backed storage adapter for CommBus.

  ## Configuration

      config :comm_bus, CommBus.Storage.Ecto,
        repo: MyApp.Repo,
        entry_schema: CommBus.Storage.Ecto.EntrySchema,
        conversation_schema: CommBus.Storage.Ecto.ConversationSchema

  Only `:repo` is required; the schema modules default to the ones bundled with
  CommBus. Projects may override them to extend fields or change table names.
  """

  @behaviour CommBus.Storage.EntryStore
  @behaviour CommBus.Storage.ConversationStore

  alias CommBus.Storage.EctoAdapter
  alias CommBus.Storage.Ecto.{ConversationSchema, EntrySchema}

  @doc "Delegates entry storage to the EctoAdapter with this module's configuration."
  @impl true
  def store_entry(entry), do: EctoAdapter.store_entry(entry, config())

  @doc "Delegates entry listing to the EctoAdapter with this module's configuration."
  @impl true
  def list_entries(opts), do: EctoAdapter.list_entries(opts, config())

  @doc "Delegates entry lookup to the EctoAdapter with this module's configuration."
  @impl true
  def get_entry(id), do: EctoAdapter.get_entry(id, config())

  @doc "Delegates entry deletion to the EctoAdapter with this module's configuration."
  @impl true
  def delete_entry(id), do: EctoAdapter.delete_entry(id, config())

  @doc "Delegates conversation storage to the EctoAdapter with this module's configuration."
  @impl true
  def store_conversation(conversation), do: EctoAdapter.store_conversation(conversation, config())

  @doc "Delegates conversation loading to the EctoAdapter with this module's configuration."
  @impl true
  def load_conversation(id), do: EctoAdapter.load_conversation(id, config())

  @doc "Delegates conversation update to the EctoAdapter with this module's configuration."
  @impl true
  def update_conversation(id, updates), do: EctoAdapter.update_conversation(id, updates, config())

  defp config do
    env_config = Application.get_env(:comm_bus, __MODULE__, [])

    repo = Keyword.fetch!(env_config, :repo)
    entry_schema = Keyword.get(env_config, :entry_schema, EntrySchema)
    conversation_schema = Keyword.get(env_config, :conversation_schema, ConversationSchema)

    %{
      repo: repo,
      entry_schema: entry_schema,
      conversation_schema: conversation_schema
    }
  end
end
