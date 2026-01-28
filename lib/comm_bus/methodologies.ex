defmodule CommBus.Methodologies do
  @moduledoc """
  Curated methodology catalog for reusable prompt packs.

  Loads YAML definitions from `config/comm_bus/methodologies` by default, validates schema,
  and exposes helpers to retrieve methodology metadata or resolve entries for injection.
  """

  alias CommBus.{Entry, Methodology}

  @cache_key {__MODULE__, :catalog}
  @default_root Path.expand("config/comm_bus/methodologies", File.cwd!())

  @spec default_root() :: String.t()
  def default_root do
    Application.get_env(:comm_bus, :methodology_root, @default_root)
  end

  @spec load_from_disk!(keyword()) :: %{String.t() => Methodology.t()}
  def load_from_disk!(opts \\ []) do
    root = Keyword.get(opts, :root, default_root())

    methodologies =
      root
      |> Path.join("**/*.y*ml")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&load_file!(&1, root))

    catalog = Map.new(methodologies, &{&1.slug, &1})
    :persistent_term.put(@cache_key, catalog)
    catalog
  end

  @spec list() :: [Methodology.t()]
  def list do
    catalog()
    |> Map.values()
    |> Enum.sort_by(& &1.slug)
  end

  @spec get!(String.t()) :: Methodology.t()
  def get!(slug) do
    case Map.fetch(catalog(), slug) do
      {:ok, methodology} -> methodology
      :error -> raise ArgumentError, "methodology not found: #{slug}"
    end
  end

  @spec entries_for(String.t() | [String.t()]) :: [Entry.t()]
  def entries_for(refs) when is_list(refs) do
    refs
    |> Enum.flat_map(&entries_for/1)
  end

  def entries_for(ref) when is_binary(ref) do
    case String.split(ref, "#", parts: 2) do
      [slug, entry_id] ->
        get!(slug).entries |> Enum.filter(&match_entry?(&1, entry_id))

      [slug] ->
        get!(slug).entries
    end
  end

  @spec reload!() :: %{String.t() => Methodology.t()}
  def reload!, do: load_from_disk!()

  @spec clear_cache!() :: :ok
  def clear_cache! do
    :persistent_term.erase(@cache_key)
    :ok
  end

  defp catalog do
    case :persistent_term.get(@cache_key, :undefined) do
      :undefined ->
        load_from_disk!()
        :persistent_term.get(@cache_key)

      catalog ->
        catalog
    end
  end

  defp load_file!(path, root) do
    data =
      case YamlElixir.read_from_file(path, atoms: false) do
        {:ok, map} when is_map(map) -> map
        {:ok, _other} -> raise_schema_error(path, "expected top-level map")
        {:error, reason} -> raise "failed to read #{path}: #{inspect(reason)}"
      end

    attrs = stringify_keys(data)
    slug = Map.get(attrs, "slug") || default_slug(path, root)
    name = fetch_string!(attrs, "name", path)
    description = fetch_string!(attrs, "description", path)
    tags = list_strings(attrs, "tags")
    entries = build_entries(attrs, path)

    %Methodology{slug: slug, name: name, description: description, tags: tags, entries: entries}
  end

  defp build_entries(attrs, path) do
    case Map.get(attrs, "entries") do
      list when is_list(list) and list != [] -> Enum.map(list, &build_entry(&1, path))
      [] -> raise_schema_error(path, "entries list cannot be empty")
      _ -> raise_schema_error(path, "entries must be a list")
    end
  end

  defp build_entry(entry, path) when is_map(entry) do
    attrs = stringify_keys(entry)

    content = Map.get(attrs, "content") || raise_schema_error(path, "entry missing content")
    section = attrs |> Map.get("section", "pre_history") |> to_atom(:section, path)
    mode = attrs |> Map.get("mode", "triggered") |> to_atom(:mode, path)
    match_mode = attrs |> Map.get("match_mode", "any") |> to_atom(:match_mode, path)
    match_strategy = attrs |> Map.get("match_strategy", "exact") |> to_atom(:match_strategy, path)

    %Entry{
      id: Map.get(attrs, "id"),
      content: content,
      keywords: list_strings(attrs, "keywords"),
      priority: Map.get(attrs, "priority", 0),
      weight: Map.get(attrs, "weight", 0),
      enabled: Map.get(attrs, "enabled", true),
      mode: mode,
      match_mode: match_mode,
      match_strategy: match_strategy,
      section: section,
      metadata: Map.get(attrs, "metadata", %{}),
      scan_depth: Map.get(attrs, "scan_depth"),
      cooldown_turns: Map.get(attrs, "cooldown_turns"),
      match_threshold: Map.get(attrs, "match_threshold"),
      fuzzy_threshold: Map.get(attrs, "fuzzy_threshold"),
      semantic_hints: list_strings(attrs, "semantic_hints"),
      semantic_threshold: Map.get(attrs, "semantic_threshold"),
      exclude_keywords: list_strings(attrs, "exclude_keywords")
    }
  end

  defp build_entry(_other, path) do
    raise_schema_error(path, "entries must be maps")
  end

  defp default_slug(path, root) do
    path
    |> Path.relative_to(root)
    |> Path.rootname()
    |> String.replace(~r/\s+/, "-")
  end

  defp fetch_string!(map, key, path) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> value
      _ -> raise_schema_error(path, "missing or invalid #{key}")
    end
  end

  defp list_strings(map, key) do
    case Map.get(map, key) do
      nil -> []
      value when is_list(value) -> Enum.map(value, &to_string/1)
      value -> [to_string(value)]
    end
  end

  defp to_atom(value, _field, _path) when is_atom(value), do: value

  defp to_atom(value, field, path) when is_binary(value) do
    String.to_atom(String.downcase(value))
  rescue
    ArgumentError -> raise_schema_error(path, "invalid #{field} value: #{value}")
  end

  defp stringify_keys(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      cond do
        is_atom(k) -> {Atom.to_string(k), v}
        is_binary(k) -> {k, v}
        true -> raise "invalid key #{inspect(k)}"
      end
    end
  end

  defp match_entry?(%Entry{id: nil}, _id), do: false
  defp match_entry?(%Entry{id: id}, target), do: to_string(id) == target

  defp raise_schema_error(path, message) do
    raise ArgumentError, "invalid methodology #{path}: #{message}"
  end
end
