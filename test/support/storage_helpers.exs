defmodule CommBus.Test.EntrySchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:content, :string)
    field(:keywords, {:array, :string}, default: [])
    field(:priority, :integer)
    field(:weight, :integer)
    field(:token_count, :integer)
    field(:enabled, :boolean, default: true)
    field(:mode, Ecto.Enum, values: [:constant, :triggered], default: :triggered)
    field(:match_mode, Ecto.Enum, values: [:any, :all], default: :any)

    field(:section, Ecto.Enum,
      values: [:system, :pre_history, :history, :post_history],
      default: :pre_history
    )

    field(:metadata, :map, default: %{})
  end

  def changeset(entry, attrs) do
    cast(entry, attrs, __schema__(:fields))
  end
end

defmodule CommBus.Test.ConversationSchema do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :integer)
    field(:messages, {:array, :map}, default: [])
    field(:depth, :integer)
    field(:metadata, :map, default: %{})
  end

  def changeset(conversation, attrs) do
    cast(conversation, attrs, __schema__(:fields))
  end
end

defmodule CommBus.Test.FakeRepo do
  use Agent

  alias Ecto.Changeset

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def insert_or_update(%Changeset{} = changeset) do
    schema = changeset.data.__struct__
    record = ensure_id(Changeset.apply_changes(changeset))

    Agent.get_and_update(__MODULE__, fn state ->
      bucket = Map.get(state, schema, %{})
      bucket = Map.put(bucket, record.id, record)
      new_state = Map.put(state, schema, bucket)
      {{:ok, record}, new_state}
    end)
  end

  def all(schema) do
    Agent.get(__MODULE__, fn state ->
      state |> Map.get(schema, %{}) |> Map.values()
    end)
  end

  def get(schema, id) do
    Agent.get(__MODULE__, fn state ->
      state |> Map.get(schema, %{}) |> Map.get(id)
    end)
  end

  def delete(record) do
    schema = record.__struct__

    Agent.update(__MODULE__, fn state ->
      bucket = Map.get(state, schema, %{})
      %{state | schema => Map.delete(bucket, record.id)}
    end)

    {:ok, record}
  end

  defp ensure_id(%{id: nil} = record) do
    %{record | id: System.unique_integer([:positive])}
  end

  defp ensure_id(record), do: record
end
