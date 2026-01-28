defmodule CommBus.Prompts.OverrideStore.Memory do
  @moduledoc "In-memory override store for testing and local usage."

  @behaviour CommBus.Prompts.OverrideStore

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> [] end, name: name)
  end

  @impl true
  def create_override(attrs) when is_map(attrs) do
    name = Map.get(attrs, :name, __MODULE__)
    override = normalize_override(attrs)

    Agent.update(name, fn overrides -> [override | overrides] end)
    {:ok, override}
  end

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
