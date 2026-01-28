defmodule CommBus.Storage.EntryStore do
  @moduledoc "Behaviour for entry persistence."

  @callback store_entry(CommBus.Entry.t()) :: {:ok, CommBus.Entry.t()} | {:error, term()}
  @callback list_entries(keyword()) :: {:ok, [CommBus.Entry.t()]} | {:error, term()}
  @callback get_entry(term()) :: {:ok, CommBus.Entry.t()} | {:error, :not_found}
  @callback delete_entry(term()) :: :ok | {:error, term()}
end

defmodule CommBus.Storage.ConversationStore do
  @moduledoc "Behaviour for conversation persistence."

  @callback store_conversation(CommBus.Conversation.t()) ::
              {:ok, CommBus.Conversation.t()} | {:error, term()}

  @callback load_conversation(term()) :: {:ok, CommBus.Conversation.t()} | {:error, :not_found}
  @callback update_conversation(term(), map()) ::
              {:ok, CommBus.Conversation.t()} | {:error, term()}
end

defmodule CommBus.Storage do
  @moduledoc false

  @default_store CommBus.Storage.InMemory

  @doc """
  Resolve the configured entry store module, allowing optional overrides.
  """
  @spec entry_store(module() | nil) :: module()
  def entry_store(module_override \\ nil) do
    resolve_store(module_override, :entry_store)
  end

  @doc """
  Resolve the configured conversation store module, allowing optional overrides.
  """
  @spec conversation_store(module() | nil) :: module()
  def conversation_store(module_override \\ nil) do
    resolve_store(module_override, :conversation_store)
  end

  defp resolve_store(module_override, config_key) do
    module =
      module_override ||
        Application.get_env(:comm_bus, config_key) ||
        Application.get_env(:comm_bus, :entry_store) ||
        @default_store

    ensure_loaded!(module)
    module
  end

  defp ensure_loaded!(module) do
    unless Code.ensure_loaded?(module) do
      raise ArgumentError, "module #{inspect(module)} is not available"
    end
  end
end
