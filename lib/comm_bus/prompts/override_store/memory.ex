defmodule CommBus.Prompts.OverrideStore.Memory do
  @moduledoc "In-memory override store for testing and local usage."

  @behaviour CommBus.Prompts.OverrideStore

  @doc """
  Starts the in-memory override store backed by an Agent process.

  ## Parameters

    - `opts` — Keyword options: `:name` (process name, defaults to module name).

  ## Returns

  `{:ok, pid}` on success.
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> [] end, name: name)
  end

  @doc """
  Stores a new prompt override in the in-memory agent. The override map
  should contain `:slug`, `:content`, and optionally `:scope`, `:metadata`,
  `:active`, and `:priority` keys.

  ## Parameters

    - `attrs` — A map of override attributes.

  ## Returns

  `{:ok, normalized_override}` on success.
  """
  @impl true
  def create_override(attrs) when is_map(attrs) do
    name = Map.get(attrs, :name, __MODULE__)
    override = normalize_override(attrs)

    Agent.update(name, fn overrides -> [override | overrides] end)
    {:ok, override}
  end

  @doc """
  Retrieves the highest-priority active override for the given prompt slug,
  optionally filtered by scope.

  ## Parameters

    - `slug` — The prompt slug to look up.
    - `opts` — Keyword options: `:name` (agent name), `:scope` (filter by scope).

  ## Returns

  A map with `:slug`, `:content`, `:scope`, `:metadata`, `:active`, `:priority`
  keys, or `nil` if no active override exists.
  """
  @impl true
  def get_active_override(slug, opts \\ []) when is_binary(slug) do
    name = Keyword.get(opts, :name, __MODULE__)
    scope = Keyword.get(opts, :scope)

    Agent.get(name, fn overrides ->
      overrides
      |> Enum.filter(&(&1.slug == slug))
      |> maybe_scope(scope)
      |> Enum.filter(& &1.active)
      |> Enum.sort_by(& &1.priority, :desc)
      |> List.first()
    end)
  end

  defp normalize_override(attrs) do
    %{
      slug: Map.get(attrs, :slug) || Map.get(attrs, "slug"),
      content: Map.get(attrs, :content) || Map.get(attrs, "content"),
      scope: Map.get(attrs, :scope) || Map.get(attrs, "scope"),
      metadata: Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{},
      active: Map.get(attrs, :active, true),
      priority: Map.get(attrs, :priority, 0)
    }
  end

  defp maybe_scope(overrides, nil), do: overrides

  defp maybe_scope(overrides, scope) do
    Enum.filter(overrides, fn override ->
      override.scope == scope or override.metadata["scope"] == scope
    end)
  end
end
