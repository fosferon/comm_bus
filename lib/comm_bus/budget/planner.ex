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
