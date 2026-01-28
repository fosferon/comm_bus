defmodule CommBus.Storage.EctoAdapter do
  @moduledoc """
  Generic helper that persists CommBus entries and conversations using any Ecto repo.

  The adapter expects a configuration map with the following keys:

    * `:repo` - Ecto repo module implementing `insert_or_update/1`, `all/1`, `get/2`, `delete/1`
    * `:entry_schema` - schema module with `changeset/2` (or rely on `Ecto.Changeset.change/2`)
    * `:conversation_schema` - schema module for conversations

  This module does not implement the behaviours directly; instead, concrete modules
  (e.g. `CommBus.Storage.DevMan`) delegate to it.
  """

  alias CommBus.{Conversation, Entry}

  @type config :: %{
          required(:repo) => module(),
          required(:entry_schema) => module(),
          required(:conversation_schema) => module()
        }

  # -- Entry operations ----------------------------------------------------

  @spec store_entry(Entry.t(), config()) :: {:ok, Entry.t()} | {:error, term()}
  def store_entry(%Entry{} = entry, config) do
    with {:ok, record} <- upsert(entry, config, :entry_schema) do
      {:ok, record_to_entry(record)}
    end
  end

  @spec list_entries(keyword(), config()) :: {:ok, [Entry.t()]} | {:error, term()}
  def list_entries(opts, config) do
    entries =
      repo(config)
      |> repo_all(entry_schema(config))
      |> Enum.map(&record_to_entry/1)
      |> filter_entries(opts)

    {:ok, entries}
  end

  @spec get_entry(term(), config()) :: {:ok, Entry.t()} | {:error, :not_found}
  def get_entry(id, config) do
    with {:ok, record} <- repo_get(repo(config), entry_schema(config), id) do
      {:ok, record_to_entry(record)}
    end
  end

  @spec delete_entry(term(), config()) :: :ok | {:error, term()}
  def delete_entry(id, config) do
    with {:ok, record} <- repo_get(repo(config), entry_schema(config), id) do
      repo_delete(repo(config), record)
    end
  end

  # -- Conversation operations --------------------------------------------

  @spec store_conversation(Conversation.t(), config()) ::
          {:ok, Conversation.t()} | {:error, term()}
  def store_conversation(%Conversation{} = conversation, config) do
    with {:ok, record} <- upsert(conversation, config, :conversation_schema) do
      {:ok, record_to_conversation(record)}
    end
  end

  @spec load_conversation(term(), config()) :: {:ok, Conversation.t()} | {:error, :not_found}
  def load_conversation(id, config) do
    with {:ok, record} <- repo_get(repo(config), conversation_schema(config), id) do
      {:ok, record_to_conversation(record)}
    end
  end

  @spec update_conversation(term(), map(), config()) :: {:ok, Conversation.t()} | {:error, term()}
  def update_conversation(id, updates, config) when is_map(updates) do
    with {:ok, record} <- repo_get(repo(config), conversation_schema(config), id) do
      attrs = record |> Map.from_struct() |> Map.merge(updates)
      changeset = build_changeset(conversation_schema(config), record, attrs)

      case repo_insert_or_update(repo(config), changeset) do
        {:ok, result} -> {:ok, record_to_conversation(result)}
        error -> error
      end
    end
  end

  # -- Helpers --------------------------------------------------------------

  defp upsert(struct, config, schema_key) do
    schema_module = Map.fetch!(config, schema_key)
    attrs = Map.from_struct(struct)
    record = struct(schema_module)
    changeset = build_changeset(schema_module, record, attrs)
    repo_insert_or_update(repo(config), changeset)
  end

  defp build_changeset(schema_module, record, attrs) do
    cond do
      function_exported?(schema_module, :changeset, 2) ->
        apply(schema_module, :changeset, [record, attrs])

      Code.ensure_loaded?(Ecto.Changeset) ->
        Ecto.Changeset.change(record, attrs)

      true ->
        raise_missing_ecto!()
    end
  end

  defp repo_insert_or_update(repo, changeset) do
    ensure_repo_functions!(repo, :insert_or_update)
    apply(repo, :insert_or_update, [changeset])
  end

  defp repo_all(repo, schema) do
    ensure_repo_functions!(repo, :all)
    apply(repo, :all, [schema])
  end

  defp repo_get(repo, schema, id) do
    ensure_repo_functions!(repo, :get)

    case apply(repo, :get, [schema, id]) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  defp repo_delete(repo, record) do
    ensure_repo_functions!(repo, :delete)
    apply(repo, :delete, [record])
    :ok
  end

  defp record_to_entry(record) do
    attrs = Map.from_struct(record)
    build_struct(Entry, attrs)
  end

  defp record_to_conversation(record) do
    attrs = Map.from_struct(record)
    build_struct(Conversation, attrs)
  end

  defp build_struct(module, attrs) do
    keys = Map.keys(struct(module)) -- [:__struct__]
    attrs = attrs |> Map.take(keys) |> Map.put_new(:metadata, attrs[:metadata] || %{})
    struct(module, attrs)
  end

  defp filter_entries(entries, opts) do
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

  defp ensure_repo_functions!(repo, fun) do
    unless function_exported?(repo, fun, arity_for(fun)) do
      raise ArgumentError,
            "#{inspect(repo)} must implement #{fun}/#{arity_for(fun)} to be used as a CommBus storage repo"
    end
  end

  defp arity_for(:insert_or_update), do: 1
  defp arity_for(:all), do: 1
  defp arity_for(:get), do: 2
  defp arity_for(:delete), do: 1

  defp raise_missing_ecto! do
    raise "Ecto.Changeset is required. Add {:ecto, \"~> 3.11\"} to your dependencies."
  end

  defp repo(config), do: Map.fetch!(config, :repo)
  defp entry_schema(config), do: Map.fetch!(config, :entry_schema)
  defp conversation_schema(config), do: Map.fetch!(config, :conversation_schema)
end
