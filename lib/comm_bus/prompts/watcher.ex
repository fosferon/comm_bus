defmodule CommBus.Prompts.Watcher do
  @moduledoc false

  use GenServer
  require Logger

  @doc """
  Starts the file system watcher GenServer that monitors the prompt directory
  for changes and triggers automatic prompt reloads with debouncing.

  ## Parameters

    - `opts` — Keyword options: `:root` (prompt directory), `:schema` (validation schema),
      `:debounce_ms` (debounce interval, default 150ms).

  ## Returns

  `{:ok, pid}` on success.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    root = Keyword.get(opts, :root, CommBus.Prompts.default_root())
    schema = Keyword.get(opts, :schema, :flex)
    debounce_ms = Keyword.get(opts, :debounce_ms, 150)

    state = %{
      root: Path.expand(root),
      schema: schema,
      debounce_ms: debounce_ms,
      pending: MapSet.new(),
      timer_ref: nil,
      watcher_pid: nil
    }

    if File.dir?(state.root) do
      {:ok, watcher_pid} = FileSystem.start_link(dirs: [state.root])
      FileSystem.subscribe(watcher_pid)
      {:ok, %{state | watcher_pid: watcher_pid}}
    else
      Logger.info("Prompt watcher skipped; directory missing: #{state.root}")
      {:ok, state}
    end
  end

  @impl true
  def handle_info({:file_event, _worker, {path, _events}}, state) do
    state =
      if relevant_path?(state.root, path) do
        state
        |> put_pending(path)
        |> schedule_flush()
      else
        state
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(:flush, state) do
    if MapSet.size(state.pending) > 0 do
      Logger.info("Reloading prompts due to changes")
      CommBus.Prompts.load_from_disk!(root: state.root, schema: state.schema)
    end

    {:noreply, %{state | pending: MapSet.new(), timer_ref: nil}}
  end

  defp relevant_path?(root, path) do
    String.starts_with?(path, root) and String.ends_with?(path, ".md")
  end

  defp put_pending(state, path), do: %{state | pending: MapSet.put(state.pending, path)}

  defp schedule_flush(%{timer_ref: nil} = state) do
    ref = Process.send_after(self(), :flush, state.debounce_ms)
    %{state | timer_ref: ref}
  end

  defp schedule_flush(%{timer_ref: ref} = state) when is_reference(ref) do
    Process.cancel_timer(ref)
    new_ref = Process.send_after(self(), :flush, state.debounce_ms)
    %{state | timer_ref: new_ref}
  end
end
