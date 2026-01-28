defmodule CommBus.Storage.HuMan do
  @moduledoc """
  Storage adapter targeting HuMan's PostgreSQL persistence layer.

  Configure in HuMan:

      config :comm_bus, CommBus.Storage.HuMan,
        repo: HuMan.Repo,
        entry_schema: HuMan.Context.Entry,
        conversation_schema: HuMan.Context.Conversation

  ## Migration checklist

  1. Configure the adapter as above and run the HuMan migrations for the CommBus tables.
  2. Execute `mix comm_bus.entries --store CommBus.Storage.HuMan` to validate connectivity.
  3. Dry-run prompt assemblies with `mix comm_bus.simulate --conversation priv/comm_bus/sample.yml --store CommBus.Storage.HuMan`.
  4. Pipe the `[:comm_bus, :context, :metrics]` telemetry event into your observability stack
     (see `CommBus.Telemetry.metrics/0`) to monitor inclusion rates and budget waste after migration.
  """

  @behaviour CommBus.Storage.EntryStore
  @behaviour CommBus.Storage.ConversationStore

  alias CommBus.Storage.EctoAdapter

  @impl true
  def store_entry(entry), do: EctoAdapter.store_entry(entry, config())

  @impl true
  def list_entries(opts), do: EctoAdapter.list_entries(opts, config())

  @impl true
  def get_entry(id), do: EctoAdapter.get_entry(id, config())

  @impl true
  def delete_entry(id), do: EctoAdapter.delete_entry(id, config())

  @impl true
  def store_conversation(conversation), do: EctoAdapter.store_conversation(conversation, config())

  @impl true
  def load_conversation(id), do: EctoAdapter.load_conversation(id, config())

  @impl true
  def update_conversation(id, updates), do: EctoAdapter.update_conversation(id, updates, config())

  defp config do
    env_config =
      Application.get_env(:comm_bus, __MODULE__) ||
        raise "Missing config for #{inspect(__MODULE__)}. See module docs for setup instructions."

    Map.new(env_config)
  end
end
