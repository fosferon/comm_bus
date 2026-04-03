defmodule CommBus.Budget.Planner do
  @moduledoc """
  Simple helper for deriving section budgets and completion allowances.

  ## Example

      plan = CommBus.Budget.Planner.plan(total: 8000, completion: 1000)
      # => %{total: 8000, completion: 1000, sections: %{system: 800, pre_history: 2400, history: 3200, post_history: 1600}}
  """

  @default_ratios %{
    system: 0.1,
    pre_history: 0.3,
    history: 0.4,
    post_history: 0.2
  }

  @doc """
  Computes a budget plan that allocates tokens across prompt sections.

  Subtracts the completion reserve from the total budget, then distributes
  the remainder across sections using the provided ratios (or defaults:
  system 10%, pre_history 30%, history 40%, post_history 20%).

  ## Parameters

    - `opts` — Keyword list with:
      - `:total` (required) — Total token budget for the context window.
      - `:completion` — Tokens reserved for LLM completion (default: total ÷ 4).
      - `:section_ratios` — Map of section atoms to ratio floats.

  ## Returns

  A map with `:total`, `:completion`, and `:sections` (map of section → token count).
  """
  @spec plan(keyword()) :: %{total: pos_integer(), completion: non_neg_integer(), sections: map()}
  def plan(opts) do
    total = Keyword.fetch!(opts, :total)
    completion = Keyword.get(opts, :completion, div(total, 4))
    ratios = Keyword.get(opts, :section_ratios, @default_ratios)

    sections = allocate_sections(total - completion, ratios)

    %{total: total, completion: completion, sections: sections}
  end

  defp allocate_sections(available, ratios) do
    total_ratio = Enum.reduce(ratios, 0, fn {_section, ratio}, acc -> acc + ratio end)

    Enum.reduce(ratios, %{}, fn {section, ratio}, acc ->
      share = ratio / total_ratio
      Map.put(acc, section, trunc(available * share))
    end)
  end
end
