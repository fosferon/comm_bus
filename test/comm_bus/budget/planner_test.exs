defmodule CommBus.Budget.PlannerTest do
  use ExUnit.Case, async: true

  alias CommBus.Budget.Planner

  test "plans budgets with defaults" do
    plan = Planner.plan(total: 8000)
    assert plan.total == 8000
    assert plan.completion == 2000

    assert plan.sections.system + plan.sections.pre_history + plan.sections.history +
             plan.sections.post_history == 6000
  end

  test "supports custom ratios and completion" do
    plan =
      Planner.plan(total: 6000, completion: 1000, section_ratios: %{system: 0.2, history: 0.8})

    assert plan.completion == 1000
    assert plan.sections.system == 1000
    assert plan.sections.history == 4000
  end
end
