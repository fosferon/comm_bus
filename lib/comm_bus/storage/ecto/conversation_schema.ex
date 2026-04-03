defmodule CommBus.Storage.Ecto.ConversationSchema do
  @moduledoc """
  Default Ecto schema used by CommBus.Storage.Ecto for persisting conversations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  schema "comm_bus_conversations" do
    field(:messages, {:array, :map}, default: [])
    field(:depth, :integer, default: 0)
    field(:metadata, :map, default: %{})

    timestamps()
  end

  @doc false
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:messages, :depth, :metadata])
  end
end
