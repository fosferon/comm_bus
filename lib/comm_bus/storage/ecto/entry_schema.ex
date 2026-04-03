defmodule CommBus.Storage.Ecto.EntrySchema do
  @moduledoc """
  Default Ecto schema used by CommBus.Storage.Ecto for persisting entries.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  schema "comm_bus_entries" do
    field(:content, :string)
    field(:keywords, {:array, :string}, default: [])
    field(:priority, :integer, default: 0)
    field(:weight, :integer, default: 0)
    field(:token_count, :integer, default: 0)
    field(:enabled, :boolean, default: true)

    field(:mode, Ecto.Enum,
      values: [:constant, :triggered],
      default: :triggered
    )

    field(:match_mode, Ecto.Enum,
      values: [:any, :all],
      default: :any
    )

    field(:section, Ecto.Enum,
      values: [:system, :pre_history, :history, :post_history],
      default: :pre_history
    )

    field(:metadata, :map, default: %{})

    timestamps()
  end

  @doc false
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, fields())
    |> validate_required([:content])
  end

  defp fields do
    __MODULE__.__schema__(:fields) -- [:inserted_at, :updated_at]
  end
end
