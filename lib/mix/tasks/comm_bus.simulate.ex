defmodule Mix.Tasks.CommBus.Simulate do
  use Mix.Task

  @shortdoc "Simulate a CommBus plan using local YAML fixtures"
  @moduledoc """
  Run CommBus planning locally using YAML fixtures for conversations and entries.

  ## Examples

      mix comm_bus.simulate --conversation priv/comm_bus/conversation.yml --entries priv/comm_bus/entries.yml --total 8000 --completion 1000

      mix comm_bus.simulate --conversation priv/conv.yml --store CommBus.Storage.Ecto
  """

  @switches [
    conversation: :string,
    entries: :string,
    store: :string,
    total: :integer,
    completion: :integer,
    section: :keep,
    methodology: :keep
  ]

  alias CommBus.{CLI, Context, Methodologies}

  @doc """
  Runs a full CommBus assembly simulation using YAML fixture files for the
  conversation and entries, printing the plan with included/excluded entries,
  token usage, and exclusion reasons.

  ## Parameters

    - `args` — Command-line argument list; requires `--conversation`.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    conversation_path = opts[:conversation] || Mix.raise("--conversation path is required")
    conversation = CLI.conversation_from_file!(conversation_path)

    entries =
      load_entries(opts[:entries]) ++
        load_store_entries(opts) ++
        Methodologies.entries_for(Keyword.get_values(opts, :methodology))

    if entries == [] do
      Mix.raise("no entries provided via --entries or storage adapter")
    end

    plan_opts = build_plan_opts(opts)
    plan = Context.plan(conversation, entries, plan_opts)

    print_plan(plan)
  end

  defp load_entries(nil), do: []
  defp load_entries(path), do: CLI.entries_from_file!(path)

  defp load_store_entries(opts) do
    store = CLI.resolve_entry_store(opts)

    case store.list_entries([]) do
      {:ok, entries} ->
        entries

      {:error, reason} ->
        Mix.raise("unable to load entries from #{inspect(store)}: #{inspect(reason)}")
    end
  end

  defp build_plan_opts(opts) do
    ratios = CLI.parse_section_ratios(Keyword.get_values(opts, :section))

    plan_keywords =
      CLI.budget_plan_opts(
        total: opts[:total],
        completion: opts[:completion],
        section_ratios: if(ratios == %{}, do: nil, else: ratios)
      )

    case plan_keywords do
      nil -> []
      plan -> [budget: %{plan: plan}]
    end
  end

  defp print_plan(plan) do
    Mix.shell().info("Conversation: #{inspect(plan.conversation.id)}")
    Mix.shell().info("Included entries: #{length(plan.included_entries)}")
    Mix.shell().info("Excluded entries: #{length(plan.exclusions)}")
    Mix.shell().info("Token usage: #{inspect(plan.token_usage)}")

    Mix.shell().info("\nSections:")

    plan.sections
    |> Enum.each(fn {section, entries} ->
      Mix.shell().info("  #{section} (#{length(entries)} entries)")
    end)

    Mix.shell().info("\nExclusions:")

    if plan.exclusions == [] do
      Mix.shell().info("  (none)")
    else
      plan.exclusions
      |> Enum.each(fn exclusion ->
        Mix.shell().info(
          "  - #{inspect(exclusion.reason)} #{inspect(exclusion.entry.id || exclusion.entry.content)} #{inspect(exclusion.details)}"
        )
      end)
    end
  end
end
