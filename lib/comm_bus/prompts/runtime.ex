defmodule CommBus.Prompts.Runtime do
  @moduledoc false
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def reload, do: GenServer.cast(__MODULE__, :reload)

  @impl true
  def init(opts) do
    root = Keyword.get(opts, :root, CommBus.Prompts.default_root())
    schema = Keyword.get(opts, :schema, :flex)
    CommBus.Prompts.load_from_disk!(root: root, schema: schema)
    {:ok, %{root: root, schema: schema}}
  end

  @impl true
  def handle_cast(:reload, state) do
    CommBus.Prompts.load_from_disk!(root: state.root, schema: state.schema)
    {:noreply, state}
  end
end
