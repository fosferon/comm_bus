defmodule CommBus.Storage.Migrations do
  @moduledoc """
  Helper functions for adding CommBus tables to your Ecto migrations.

  ## Usage

      defmodule MyApp.Repo.Migrations.AddCommBusTables do
        use Ecto.Migration
        import CommBus.Storage.Migrations

        def change do
          create_comm_bus_tables()
        end
      end
  """
  @doc """
  Creates the `comm_bus_entries` and `comm_bus_conversations` tables with all
  required columns, indexes, and timestamps. Call from an Ecto migration's
  `change/0` callback.
  """
  defmacro create_comm_bus_tables do
    quote do
      create table(:comm_bus_entries, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:content, :text, null: false)
        add(:keywords, {:array, :string}, null: false, default: [])
        add(:priority, :integer, null: false, default: 0)
        add(:weight, :integer, null: false, default: 0)
        add(:token_count, :integer, null: false, default: 0)
        add(:enabled, :boolean, null: false, default: true)
        add(:mode, :string, null: false, default: "triggered")
        add(:match_mode, :string, null: false, default: "any")
        add(:section, :string, null: false, default: "pre_history")
        add(:metadata, :map, null: false, default: %{})

        timestamps(type: :utc_datetime_usec)
      end

      create(index(:comm_bus_entries, [:enabled]))
      create(index(:comm_bus_entries, [:mode]))
      create(index(:comm_bus_entries, [:section]))

      create table(:comm_bus_conversations, primary_key: false) do
        add(:id, :binary_id, primary_key: true)
        add(:messages, {:array, :map}, null: false, default: [])
        add(:depth, :integer, null: false, default: 0)
        add(:metadata, :map, null: false, default: %{})

        timestamps(type: :utc_datetime_usec)
      end
    end
  end

  @doc """
  Drops the `comm_bus_conversations` and `comm_bus_entries` tables.
  Call from an Ecto migration's `change/0` callback to reverse
  `create_comm_bus_tables/0`.
  """
  defmacro drop_comm_bus_tables do
    quote do
      drop(table(:comm_bus_conversations))
      drop(table(:comm_bus_entries))
    end
  end
end
