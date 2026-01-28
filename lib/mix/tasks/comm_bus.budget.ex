defmodule Mix.Tasks.CommBus.Budget do
  use Mix.Task

  @shortdoc "Inspect section-aware budget allocations"

  @switches [total: :integer, completion: :integer, section: :keep]

  alias CommBus.Budget.Planner
  alias CommBus.CLI

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    total = opts[:total] || Mix.raise("--total is required")
    ratios = CLI.parse_section_ratios(Keyword.get_values(opts, :section))

    plan_opts =
      [
        total: total,
        completion: opts[:completion],
        section_ratios: if(ratios == %{}, do: nil, else: ratios)
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    plan = Planner.plan(plan_opts)

    Mix.shell().info("Total budget: #{plan.total}")
    Mix.shell().info("Completion allowance: #{plan.completion}")
    Mix.shell().info("Section allocations:")

    plan.sections
    |> Enum.each(fn {section, tokens} ->
      Mix.shell().info("  #{section}: #{tokens}")
    end)
  end
end
