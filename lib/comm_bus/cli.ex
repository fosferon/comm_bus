defmodule CommBus.CLI do
  @moduledoc false

  alias CommBus.{Conversation, Entry, Message, Storage}

  @doc "Resolve an entry store module from CLI opts or application env."
  @spec resolve_entry_store(keyword()) :: module()
  def resolve_entry_store(opts) do
    opts
    |> Keyword.get(:store)
    |> module_from_option()
    |> Storage.entry_store()
  end

  @doc "Resolve a conversation store module from CLI opts or application env."
  @spec resolve_conversation_store(keyword()) :: module()
  def resolve_conversation_store(opts) do
    opts
    |> Keyword.get(:store)
    |> module_from_option()
    |> Storage.conversation_store()
  end

  @doc "Load a conversation struct from a YAML file."
  @spec conversation_from_file!(String.t()) :: CommBus.Conversation.t()
  def conversation_from_file!(path) do
    path
    |> load_yaml!()
    |> conversation_from_term!()
  end

  @doc "Load entry structs from a YAML file (list or wrapped under `entries`)."
  @spec entries_from_file!(String.t()) :: [CommBus.Entry.t()]
  def entries_from_file!(path) do
    path
    |> load_yaml!()
    |> normalize_entry_container(path)
    |> Enum.map(&entry_from_term!/1)
  end

  @doc "Parse section ratio CLI arguments such as \"system=0.2\"."
  @spec parse_section_ratios(list()) :: map()
  def parse_section_ratios(values) when is_list(values) do
    Enum.reduce(values, %{}, fn raw, acc ->
      case String.split(raw, "=", parts: 2) do
        [section, ratio] ->
          {section_atom, ratio_value} =
            {to_atom(section, :section), parse_number!(ratio, raw)}

          Map.put(acc, section_atom, ratio_value)

        _ ->
          raise ArgumentError, "invalid --section format: #{raw}"
      end
    end)
  end

  def parse_section_ratios(_), do: %{}

  @doc "Convert YAML budget options into CommBus-compatible plan keywords."
  @spec budget_plan_opts(keyword()) :: keyword() | nil
  def budget_plan_opts(opts) do
    opts
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> case do
      [] -> nil
      plan -> plan
    end
  end

  defp module_from_option(nil), do: nil

  defp module_from_option(module) when is_atom(module), do: module

  defp module_from_option(module) when is_binary(module) do
    module
    |> String.split(".", trim: true)
    |> Enum.map(&String.to_atom/1)
    |> Module.safe_concat()
  end

  defp conversation_from_term!(%{"conversation" => conversation}) do
    conversation_from_term!(conversation)
  end

  defp conversation_from_term!(%{"messages" => _} = attrs), do: build_conversation(attrs)
  defp conversation_from_term!(%{messages: _} = attrs), do: build_conversation(attrs)

  defp conversation_from_term!(other) do
    raise ArgumentError,
          "expected conversation YAML to be a map or contain a `conversation` key, got: #{inspect(other)}"
  end

  defp normalize_entry_container(%{"entries" => entries}, _path) when is_list(entries),
    do: entries

  defp normalize_entry_container(entries, _path) when is_list(entries), do: entries

  defp normalize_entry_container(_other, path) do
    raise ArgumentError,
          "expected #{path} to contain a list of entries or an `entries` key"
  end

  defp entry_from_term!(entry) when is_map(entry) do
    attrs =
      entry
      |> stringify_keys()
      |> normalise_entry_attrs()

    struct!(Entry, attrs)
  end

  defp entry_from_term!(other) do
    raise ArgumentError, "invalid entry definition: #{inspect(other)}"
  end

  defp build_conversation(attrs) do
    attrs = stringify_keys(attrs)

    messages =
      attrs
      |> Map.get("messages", [])
      |> Enum.map(&build_message/1)

    %Conversation{
      id: Map.get(attrs, "id"),
      metadata: Map.get(attrs, "metadata", %{}),
      messages: messages
    }
  end

  defp build_message(message) when is_map(message) do
    attrs = stringify_keys(message)

    %Message{
      role: attrs |> Map.get("role", "user") |> to_atom(:role),
      content: Map.get(attrs, "content", ""),
      metadata: Map.get(attrs, "metadata", %{})
    }
  end

  defp normalise_entry_attrs(attrs) do
    %{
      id: Map.get(attrs, "id"),
      content: Map.get(attrs, "content", ""),
      keywords: list_field(attrs, "keywords"),
      priority: Map.get(attrs, "priority", 0),
      weight: Map.get(attrs, "weight", 0),
      enabled: Map.get(attrs, "enabled", true),
      mode: attrs |> Map.get("mode", "triggered") |> to_atom(:mode),
      match_mode: attrs |> Map.get("match_mode", "any") |> to_atom(:match_mode),
      match_strategy: attrs |> Map.get("match_strategy", "exact") |> to_atom(:match_strategy),
      section: attrs |> Map.get("section", "pre_history") |> to_atom(:section),
      metadata: Map.get(attrs, "metadata") || %{},
      scan_depth: Map.get(attrs, "scan_depth"),
      cooldown_turns: Map.get(attrs, "cooldown_turns"),
      match_threshold: Map.get(attrs, "match_threshold"),
      fuzzy_threshold: Map.get(attrs, "fuzzy_threshold"),
      semantic_hints: list_field(attrs, "semantic_hints"),
      semantic_threshold: Map.get(attrs, "semantic_threshold"),
      exclude_keywords: list_field(attrs, "exclude_keywords")
    }
  end

  defp load_yaml!(path) do
    case YamlElixir.read_from_file(path, atoms: false) do
      {:ok, data} -> data
      {:error, reason} -> raise ArgumentError, "unable to read #{path}: #{inspect(reason)}"
    end
  end

  defp stringify_keys(map) do
    map
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} when is_binary(k) -> {k, v}
    end)
    |> Enum.into(%{})
  end

  defp to_atom(value, _field) when is_atom(value), do: value

  defp to_atom(value, field) when is_binary(value) do
    value
    |> String.downcase()
    |> String.to_atom()
  rescue
    ArgumentError ->
      raise ArgumentError, "invalid #{field} value: #{value}"
  end

  defp parse_number!(value, _original) when is_number(value), do: value

  defp parse_number!(value, original) when is_binary(value) do
    cond do
      value == "" -> raise ArgumentError, "invalid number: #{original}"
      String.contains?(value, ".") -> String.to_float(value)
      true -> String.to_integer(value)
    end
  rescue
    ArgumentError -> raise ArgumentError, "invalid number: #{original}"
  end

  defp list_field(attrs, key) do
    case Map.get(attrs, key) do
      nil -> []
      value when is_list(value) -> value
      value -> [value]
    end
  end
end
