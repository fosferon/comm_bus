defmodule CommBus.Context do
  @moduledoc """
  High-level planning utilities for CommBus assemblies.

  Produces diffable plans with budget allocations, diagnostics, and exclusion reasons,
  and emits telemetry events for observability.
  """

  alias CommBus.{Budget, Conversation, Entry, Matcher, Methodologies, Tokenizer}

  @telemetry_event [:comm_bus, :context, :plan]
  @metrics_event [:comm_bus, :context, :metrics]

  defmodule Plan do
    @moduledoc "Structured plan returned by `CommBus.Context.plan/3`."

    @enforce_keys [:conversation, :sections, :included_entries, :excluded_entries]
    defstruct conversation: nil,
              budget: %{},
              sections: %{},
              included_entries: [],
              excluded_entries: [],
              token_usage: %{},
              candidates: [],
              match_diagnostics: [],
              match_context: %{},
              exclusions: []
  end

  defmodule Exclusion do
    @moduledoc "Represents a reason an entry was dropped from the plan."
    @enforce_keys [:entry, :reason]
    defstruct entry: nil, reason: nil, details: %{}
  end

  @doc """
  Produces a comprehensive assembly plan from a conversation and entries,
  including budget allocations, match diagnostics, and exclusion reasons.

  Orchestrates the full assembly pipeline: methodology resolution, entry
  partitioning, keyword matching, deduplication, token annotation, budget
  fitting, and section positioning. Emits telemetry events for observability.

  ## Parameters

    - `conversation` — A `%CommBus.Conversation{}` with message history.
    - `entries` — List of `%CommBus.Entry{}` structs to consider.
    - `opts` — Keyword options:
      - `:budget` — Budget configuration map (see `CommBus.Budget.Planner`).
      - `:methodologies` — List of methodology refs to include.
      - `:scan_depth`, `:recency_decay` — Matching options.

  ## Returns

  A `%CommBus.Context.Plan{}` struct with sections, included/excluded entries,
  token usage, match diagnostics, and exclusion reasons.
  """
  @spec plan(Conversation.t(), [Entry.t()], keyword()) :: Plan.t()
  def plan(%Conversation{} = conversation, entries, opts \\ []) do
    :telemetry.span(@telemetry_event, %{system_time: System.system_time()}, fn ->
      plan = do_plan(conversation, entries, opts)
      metadata = telemetry_metadata(plan)
      {plan, metadata}
    end)
  end

  defp telemetry_metadata(%Plan{} = plan) do
    %{
      conversation_id: plan.conversation.id,
      included_count: length(plan.included_entries),
      excluded_count: length(plan.exclusions),
      token_usage: plan.token_usage,
      budget: plan.budget,
      exclusion_reasons:
        plan.exclusions
        |> Enum.map(& &1.reason)
        |> Enum.frequencies()
    }
  end

  defp do_plan(conversation, entries, opts) do
    methodology_entries = Methodologies.entries_for(Keyword.get(opts, :methodologies, []))
    augmented_entries = entries ++ methodology_entries

    {constants, triggered_candidates, initial_exclusions} = partition_entries(augmented_entries)

    {match_results, match_context} =
      Matcher.match_entries(conversation.messages, triggered_candidates, opts)

    triggered = Enum.map(match_results, & &1.entry)
    match_exclusions = build_match_exclusions(match_context)

    {deduped, dedup_exclusions} = dedupe_entries(constants ++ triggered)

    candidates = Tokenizer.annotate_entries(deduped, opts)

    budget =
      opts
      |> Keyword.get(:budget, %{})
      |> maybe_plan_budget()

    section_budgets = Map.get(budget, :sections, %{})
    total_budget = Map.get(budget, :total)

    {included, excluded_entries, usage, budget_exclusions} =
      allocate_entries(candidates, section_budgets, total_budget)

    sections =
      included
      |> position_entries()
      |> ensure_sections()
      |> Map.put(:history, conversation.messages)

    exclusions =
      initial_exclusions ++ match_exclusions ++ dedup_exclusions ++ budget_exclusions

    plan = %Plan{
      conversation: conversation,
      budget: budget,
      sections: sections,
      included_entries: included,
      excluded_entries: excluded_entries,
      token_usage: usage,
      candidates: candidates,
      match_diagnostics: match_results,
      match_context: match_context,
      exclusions: exclusions
    }

    emit_metrics(plan)
    plan
  end

  defp partition_entries(entries) do
    {constants, triggered, exclusions} =
      Enum.reduce(entries, {[], [], []}, fn entry, {constants, triggered, exclusions} ->
        cond do
          not entry.enabled ->
            {constants, triggered, [exclusion(entry, :disabled) | exclusions]}

          entry.mode == :constant ->
            {[entry | constants], triggered, exclusions}

          entry.mode == :triggered ->
            {constants, [entry | triggered], exclusions}

          true ->
            {constants, triggered, exclusions}
        end
      end)

    {Enum.reverse(constants), Enum.reverse(triggered), Enum.reverse(exclusions)}
  end

  defp build_match_exclusions(match_context) do
    match_context
    |> Map.get(:skipped_entries, [])
    |> Enum.map(fn %{entry: entry, reason: reason, details: details} ->
      exclusion(entry, reason, details)
    end)
  end

  defp dedupe_entries(entries) do
    {ordered, _seen, exclusions} =
      Enum.reduce(entries, {[], %{}, []}, fn entry, {acc, seen, exclusions} ->
        key = {entry.id, entry.content}

        case Map.fetch(seen, key) do
          {:ok, existing} ->
            details = %{duplicate_of: existing.id || existing.content}
            {acc, seen, [exclusion(entry, :duplicate, details) | exclusions]}

          :error ->
            {[entry | acc], Map.put(seen, key, entry), exclusions}
        end
      end)

    {Enum.reverse(ordered), Enum.reverse(exclusions)}
  end

  defp allocate_entries(candidates, section_budgets, total_budget) do
    cond do
      map_size(section_budgets) > 0 ->
        fit_by_section(candidates, section_budgets)

      is_integer(total_budget) ->
        fit_by_total(candidates, total_budget)

      true ->
        {candidates, [], %{}, []}
    end
  end

  defp fit_by_section(entries, section_budgets) do
    grouped = Enum.group_by(entries, & &1.section)

    {included, excluded, usage, exclusions} =
      Enum.reduce(grouped, {[], [], %{}, []}, fn {section, items}, {inc, exc, use, excls} ->
        limit = Map.get(section_budgets, section, 0)
        kept = Budget.fit_budget(items, limit)
        used = Enum.reduce(kept, 0, fn entry, total -> total + (entry.token_count || 0) end)
        dropped = items -- kept

        section_exclusions =
          Enum.map(dropped, fn entry ->
            exclusion(entry, :section_budget, %{
              section: section,
              budget: limit,
              tokens: entry.token_count || 0
            })
          end)

        {
          inc ++ kept,
          exc ++ dropped,
          Map.put(use, section, %{budget: limit, used: used}),
          excls ++ section_exclusions
        }
      end)

    {included, excluded, %{sections: usage}, exclusions}
  end

  defp fit_by_total(entries, limit) do
    kept = Budget.fit_budget(entries, limit)
    used = Enum.reduce(kept, 0, fn entry, total -> total + (entry.token_count || 0) end)
    dropped = entries -- kept

    exclusions =
      Enum.map(dropped, fn entry ->
        exclusion(entry, :total_budget, %{budget: limit, tokens: entry.token_count || 0})
      end)

    usage = %{total_budget: limit, used: used}
    {kept, dropped, usage, exclusions}
  end

  defp position_entries(entries) do
    entries
    |> Enum.group_by(& &1.section)
    |> Map.new(fn {section, items} ->
      {section, Enum.sort_by(items, &section_sort_key/1, :desc)}
    end)
  end

  defp section_sort_key(%Entry{} = entry) do
    {entry.weight, entry.priority, entry.id || entry.content}
  end

  defp ensure_sections(sections) do
    Enum.reduce([:system, :pre_history, :history, :post_history], sections, fn section, acc ->
      Map.put_new(acc, section, [])
    end)
  end

  defp maybe_plan_budget(%{plan: plan_opts}) when is_map(plan_opts) or is_list(plan_opts) do
    CommBus.Budget.Planner.plan(plan_opts)
  end

  defp maybe_plan_budget(opts), do: opts

  defp exclusion(entry, reason, details \\ %{}) do
    %Exclusion{entry: entry, reason: reason, details: details}
  end

  defp emit_metrics(%Plan{} = plan) do
    included = length(plan.included_entries)
    candidates = length(plan.candidates)
    usage = plan.token_usage
    used_tokens = used_tokens(usage)
    budget_cap = total_budget(usage)
    waste = compute_waste(budget_cap, used_tokens)

    measurements = %{
      inclusion_rate: inclusion_rate(included, candidates),
      included_count: included,
      candidate_count: candidates,
      budget_waste: waste,
      used_tokens: used_tokens,
      budget_total: budget_cap || 0
    }

    metadata = %{conversation_id: plan.conversation.id}

    :telemetry.execute(@metrics_event, measurements, metadata)
  end

  defp inclusion_rate(_included, 0), do: 0.0
  defp inclusion_rate(included, total), do: included / total

  defp used_tokens(%{sections: sections}) when is_map(sections) do
    sections
    |> Map.values()
    |> Enum.reduce(0, fn %{used: used}, acc -> acc + (used || 0) end)
  end

  defp used_tokens(%{used: used}) when is_integer(used), do: used
  defp used_tokens(_), do: 0

  defp total_budget(%{sections: sections}) when is_map(sections) do
    sections
    |> Map.values()
    |> Enum.reduce(0, fn %{budget: budget}, acc -> acc + (budget || 0) end)
  end

  defp total_budget(%{total_budget: budget}) when is_integer(budget), do: budget
  defp total_budget(_), do: nil

  defp compute_waste(nil, _used), do: 0
  defp compute_waste(budget, used) when budget > used, do: budget - used
  defp compute_waste(_, _), do: 0
end
