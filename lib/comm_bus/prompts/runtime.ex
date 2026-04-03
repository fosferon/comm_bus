defmodule CommBus.Prompts.Runtime do
  @moduledoc false
  use GenServer

  @doc """
  Starts the prompt runtime GenServer, which loads prompts from disk on init.

  ## Parameters

    - `opts` — Keyword options: `:root` (prompt directory), `:schema` (validation schema).

  ## Returns

  `{:ok, pid}` on success.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an asynchronous reload of all prompts from disk.

  ## Returns

  `:ok`
  """
  @spec reload() :: :ok
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
