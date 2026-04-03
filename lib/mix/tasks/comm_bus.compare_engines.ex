defmodule Mix.Tasks.CommBus.CompareEngines do
  use Mix.Task

  @shortdoc "Compare template engine outputs for golden fixtures"

  alias CommBus.Template
  alias CommBus.Template.Engine.{BbMustache, ExMustache}

  @doc """
  Compares BbMustache and ExMustache template engine outputs against golden
  fixture files, reporting matches and differences.

  ## Parameters

    - `_args` — Ignored.
  """
  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    configs = fixture_configs()

    fixture_paths()
    |> Enum.each(fn path ->
      {values, opts} = Map.get(configs, path, {%{}, [strict_mode: false]})
      compare_engines_and_report(path, values, opts)
    end)
  end

  defp compare_engines_and_report(rel_path, values, opts) do
    body = load_fixture_body(rel_path)
    opts = Keyword.merge([engine: BbMustache], opts)

    result_bb = Template.render(body, values, opts)
    result_ex = Template.render(body, values, Keyword.put(opts, :engine, ExMustache))

    case {result_bb, result_ex} do
      {{:ok, %{content: content_bb}}, {:ok, %{content: content_ex}}} ->
        if content_bb != content_ex do
          IO.puts("\n[template diff] #{rel_path}")
          print_diff(content_bb, content_ex)
        else
          IO.puts("[template match] #{rel_path}")
        end

      {error_bb, error_ex} ->
        IO.puts("\n[template error] #{rel_path}")
        IO.inspect(error_bb, label: "bbmustache")
        IO.inspect(error_ex, label: "ex_mustache")
    end
  end

  defp load_fixture_body(rel_path) do
    content = File.read!(Path.join(fixtures_dir(), rel_path))

    case String.split(content, "---\n", parts: 3) do
      ["", _front, body] -> body
      _other -> content
    end
  end

  defp print_diff(left, right) do
    left_lines = String.split(left, "\n")
    right_lines = String.split(right, "\n")

    Enum.zip(left_lines, right_lines)
    |> Enum.with_index(1)
    |> Enum.find(fn {{l, r}, _idx} -> l != r end)
    |> case do
      nil ->
        IO.puts("  No line differences detected.")

      {{l, r}, idx} ->
        IO.puts("  First diff at line #{idx}")
        IO.puts("  bb: #{l}")
        IO.puts("  ex: #{r}")
    end
  end

  defp milestone_values do
    %{
      "VERSION" => "1.0",
      "MILESTONE_NAME" => "Alpha",
      "DATE" => "2026-01-01",
      "PHASE_START" => "01",
      "PHASE_END" => "03",
      "TOTAL_PLANS" => "9",
      "MILESTONE_DESCRIPTION" => "Alpha milestone details.",
      "PHASES_SECTION" => "Phase overview section.",
      "PHASE_NUM" => "1",
      "PHASE_NAME" => "Discovery",
      "PHASE_GOAL" => "Clarify requirements",
      "DEPENDS_ON" => "None",
      "PLAN_COUNT" => "3",
      "PHASE" => "01",
      "PLAN_DESCRIPTION" => "Sample plan",
      "PHASE_DETAILS_FROM_ROADMAP" => "Roadmap details.",
      "DECISIONS_FROM_PROJECT_STATE" => "Decision log.",
      "ISSUES_RESOLVED_DURING_MILESTONE" => "Resolved issues.",
      "ISSUES_DEFERRED_TO_LATER" => "Deferred issues.",
      "SHORTCUTS_NEEDING_FUTURE_WORK" => "Tech debt.",
      "PLACEHOLDERS" => "PLACEHOLDERS"
    }
  end

  defp fixture_paths do
    Path.wildcard(Path.join(fixtures_dir(), "**/*.{md,yml,yaml}"))
    |> Enum.map(&Path.relative_to(&1, fixtures_dir()))
    |> Enum.sort()
  end

  defp fixtures_dir do
    Path.expand("test/fixtures/golden", File.cwd!())
  end

  defp fixture_configs do
    %{
      "devman/test_hello.md" => {%{"name" => "Ada"}, []},
      "devman/workflow_test_step_types.yml" =>
        {%{"step_1" => %{"output" => "x"}, "step_2" => %{"output" => "y"}}, []},
      "devman/partials_example.md" =>
        {%{"input" => "analysis"},
         [partials: %{"common/system_context" => "SYSTEM", "common/output_format" => "FORMAT"}]},
      "human/milestone_archive.md" => {milestone_values(), []}
    }
  end
end
