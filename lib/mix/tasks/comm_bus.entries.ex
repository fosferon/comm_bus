defmodule Mix.Tasks.CommBus.Entries do
  use Mix.Task

  @shortdoc "List entries from the configured storage adapter"

  @switches [store: :string, mode: :string, enabled: :boolean, keyword: :keep]

  alias CommBus.CLI

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    store = CLI.resolve_entry_store(opts)
    filters = build_filters(opts)

    case store.list_entries(filters) do
      {:ok, entries} -> print_entries(entries)
      {:error, reason} -> Mix.raise("unable to list entries: #{inspect(reason)}")
    end
  end

  defp build_filters(opts) do
    []
    |> maybe_put(:mode, opts[:mode], &parse_atom(&1, :mode))
    |> maybe_put(:enabled, opts[:enabled], & &1)
    |> maybe_put(:keywords, Keyword.get_values(opts, :keyword), &list_or_nil/1)
  end

  defp maybe_put(filters, _key, nil, _fun), do: filters

  defp maybe_put(filters, key, value, fun) do
    case fun.(value) do
      nil -> filters
      parsed -> Keyword.put(filters, key, parsed)
    end
  end

  defp parse_atom(value, _field) when is_atom(value), do: value

  defp parse_atom(value, field) when is_binary(value) do
    value
    |> String.downcase()
    |> String.to_atom()
  rescue
    ArgumentError -> Mix.raise("invalid #{field} value: #{value}")
  end

  defp list_or_nil([]), do: nil
  defp list_or_nil(list), do: list

  defp print_entries(entries) do
    total = length(entries)
    Mix.shell().info("Found #{total} entr#{if total == 1, do: "y", else: "ies"}:")

    entries
    |> Enum.sort_by(&{&1.section, &1.priority, &1.id || &1.content})
    |> Enum.with_index(1)
    |> Enum.each(fn {entry, index} ->
      Mix.shell().info(format_entry(entry, index))
    end)
  end

  defp format_entry(entry, index) do
    """
    [#{index}] #{inspect(entry.id || entry.content)}
      section: #{entry.section} | mode: #{entry.mode} | enabled: #{entry.enabled}
      priority: #{entry.priority} | weight: #{entry.weight}
      keywords: #{Enum.join(entry.keywords, ", ")}
    """
    |> String.trim_trailing()
  end
end
