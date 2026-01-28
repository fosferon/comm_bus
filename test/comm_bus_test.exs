defmodule CommBusTest do
  use ExUnit.Case

  alias CommBus.{Assembler, Conversation, Entry, Message}

  alias CommBus.Template.{
    Loader,
    Prompt,
    RenderError,
    RenderResult,
    ValidationError,
    ValidationResult
  }

  alias CommBus.Template.Engine.{BbMustache, ExMustache}

  @fixtures_dir Path.expand("fixtures/golden", __DIR__)

  test "matches keyword triggers with wildcard support" do
    messages = [
      %Message{role: :user, content: "We need accounting help."},
      %Message{role: :assistant, content: "Sure."}
    ]

    entries = [
      %Entry{id: 1, keywords: ["account*"], content: "Finance context."},
      %Entry{id: 2, keywords: ["billing"], content: "Billing context."}
    ]

    matched = CommBus.scan_triggers(messages, entries)
    assert Enum.map(matched, & &1.id) == [1]
  end

  test "matches selective entries with all keywords" do
    messages = [
      %Message{role: :user, content: "Auth and tokens are failing."}
    ]

    entries = [
      %Entry{id: 1, keywords: ["auth", "tokens"], match_mode: :all, content: "Auth info."},
      %Entry{id: 2, keywords: ["auth", "tokens"], match_mode: :any, content: "Any info."},
      %Entry{id: 3, keywords: ["auth", "billing"], match_mode: :all, content: "Billing info."}
    ]

    matched = CommBus.scan_triggers(messages, entries)
    assert Enum.map(matched, & &1.id) == [1, 2]
  end

  test "matches phrases without word boundaries" do
    messages = [
      %Message{role: :user, content: "Need single sign on."}
    ]

    entries = [
      %Entry{id: 1, keywords: ["single sign on"], content: "SSO info."},
      %Entry{id: 2, keywords: ["single"], content: "Single info."}
    ]

    matched = CommBus.scan_triggers(messages, entries)
    assert Enum.map(matched, & &1.id) == [1, 2]
  end

  test "fits entries within budget by priority" do
    entries = [
      %Entry{id: 1, token_count: 6, priority: 1},
      %Entry{id: 2, token_count: 4, priority: 2},
      %Entry{id: 3, token_count: 4, priority: 0}
    ]

    kept = CommBus.fit_budget(entries, 8)
    assert Enum.map(kept, & &1.id) == [2, 3]
  end

  test "assembles prompt sections with budgets" do
    conversation = %Conversation{
      messages: [%Message{role: :user, content: "Need help with auth."}]
    }

    entries = [
      %Entry{id: 1, mode: :constant, section: :system, token_count: 5, content: "Rules."},
      %Entry{
        id: 2,
        keywords: ["auth"],
        section: :pre_history,
        token_count: 3,
        content: "Auth info."
      },
      %Entry{
        id: 3,
        keywords: ["auth"],
        section: :pre_history,
        token_count: 4,
        content: "More auth."
      }
    ]

    result =
      Assembler.assemble_prompt(conversation, entries,
        budget: %{sections: %{system: 5, pre_history: 3}}
      )

    assert Enum.map(result.sections.system, & &1.id) == [1]
    assert Enum.map(result.sections.pre_history, & &1.id) == [2]
    assert length(result.included_entries) == 2
  end

  test "renders mustache templates" do
    assert {:ok, "Hello Ada"} = CommBus.resolve_placeholders("Hello {{name}}", %{"name" => "Ada"})
  end

  test "renders mustache templates with defaults and control tags" do
    template =
      ~s({{name | default: "Anon"}} {{#if enabled}}ON{{/if}}{{#unless enabled}}OFF{{/unless}})

    assert {:ok, "Anon OFF"} = CommBus.resolve_placeholders(template, %{})

    assert {:ok, "Ada ON"} =
             CommBus.resolve_placeholders(template, %{"name" => "Ada", "enabled" => true})
  end

  test "renders lists with each and index helpers" do
    template = ~s|{{#each items}}{{@index}}:{{this}};{{/each}}|
    assert {:ok, "0:a;1:b;"} = CommBus.resolve_placeholders(template, %{"items" => ["a", "b"]})
  end

  test "renders partials from provided map" do
    template = "Hello {{> title}}"

    assert {:ok, "Hello Dr."} =
             CommBus.resolve_placeholders(template, %{}, partials: %{"title" => "Dr."})
  end

  test "renders with metadata and partial tracking" do
    template = "Hi {{name}} {{> title}}"

    assert {:ok, %RenderResult{} = result} =
             CommBus.render_template(template, %{"name" => "Ada"}, partials: %{"title" => "Dr."})

    assert result.content == "Hi Ada Dr."
    assert Enum.sort(result.variables_used) == ["name"]
    assert Enum.sort(result.variables_provided) == ["name"]
    assert result.partials_loaded == ["title"]
    assert is_integer(result.render_time_ms)
  end

  test "coerces variables based on types" do
    template = "Count {{count}} Enabled {{enabled}}"

    assert {:ok, %RenderResult{} = result} =
             CommBus.render_template(template, %{"count" => "2", "enabled" => "true"},
               types: %{"count" => "integer", "enabled" => "boolean"}
             )

    assert result.content == "Count 2 Enabled true"
  end

  test "returns error on failed type coercion" do
    template = "Count {{count}}"

    assert {:error, %RenderError{type: :type_coercion_failed}} =
             CommBus.render_template(template, %{"count" => "abc"},
               types: %{"count" => "integer"}
             )
  end

  test "returns error when strict mode is missing variables" do
    template = "Hello {{name}}"

    assert {:error, %RenderError{type: :render_failed}} =
             CommBus.render_template(template, %{}, strict_mode: true)
  end

  test "golden devman template renders consistently across engines" do
    body = load_fixture_body("devman/test_hello.md")
    expected = "Hello Ada!\nHow are you?\n"

    assert {:ok, %RenderResult{content: content_bb}} =
             CommBus.Template.render(body, %{"name" => "Ada"}, engine: BbMustache)

    assert {:ok, %RenderResult{content: content_ex}} =
             CommBus.Template.render(body, %{"name" => "Ada"}, engine: ExMustache)

    assert content_bb == expected
    assert content_ex == expected
  end

  test "golden human template renders consistently across engines" do
    body = load_fixture_body("human/alf_mapper.md")

    assert {:ok, %RenderResult{content: content_bb}} =
             CommBus.Template.render(body, %{}, engine: BbMustache)

    assert {:ok, %RenderResult{content: content_ex}} =
             CommBus.Template.render(body, %{}, engine: ExMustache)

    assert content_bb == body
    assert content_ex == body
  end

  test "golden devman workflow template renders consistently across engines" do
    body = load_fixture_body("devman/workflow_test_step_types.yml")

    values = %{
      "step_1" => %{"output" => "input-value"},
      "step_2" => %{"output" => "FINAL"}
    }

    assert {:ok, %RenderResult{content: content_bb}} =
             CommBus.Template.render(body, values, engine: BbMustache)

    assert {:ok, %RenderResult{content: content_ex}} =
             CommBus.Template.render(body, values, engine: ExMustache)

    expected =
      String.replace(body, "{{step_1.output}}", "input-value")
      |> String.replace("{{step_2.output}}", "FINAL")

    assert content_bb == expected
    assert content_ex == expected
  end

  test "golden devman partials template renders consistently across engines" do
    body = load_fixture_body("devman/partials_example.md")

    partials = %{
      "common/system_context" => "SYSTEM_CONTEXT",
      "common/output_format" => "OUTPUT_FORMAT"
    }

    values = %{"input" => "analysis"}

    assert {:ok, %RenderResult{content: content_bb}} =
             CommBus.Template.render(body, values, engine: BbMustache, partials: partials)

    assert {:ok, %RenderResult{content: content_ex}} =
             CommBus.Template.render(body, values, engine: ExMustache, partials: partials)

    assert content_bb == content_ex
    assert String.contains?(content_bb, "SYSTEM_CONTEXT")
    assert String.contains?(content_bb, "OUTPUT_FORMAT")
    assert String.contains?(content_bb, "Now analyze: analysis")
  end

  test "golden human milestone template renders consistently across engines" do
    body = load_fixture_body("human/milestone_archive.md")
    values = milestone_values()

    assert {:ok, %RenderResult{content: content_bb}} =
             CommBus.Template.render(body, values, engine: BbMustache)

    assert {:ok, %RenderResult{content: content_ex}} =
             CommBus.Template.render(body, values, engine: ExMustache)

    assert content_bb == content_ex
    assert String.contains?(content_bb, "Milestone v1.0: Alpha")
  end

  test "engine comparison report" do
    fixtures = fixture_paths()
    configs = fixture_configs()

    Enum.each(fixtures, fn path ->
      {values, opts} = Map.get(configs, path, {%{}, [strict_mode: false]})
      compare_engines_and_report(path, values, opts)
    end)

    assert true
  end

  defp load_fixture_body(rel_path) do
    content = File.read!(Path.join(@fixtures_dir, rel_path))

    case String.split(content, "---\n", parts: 3) do
      ["", _front, body] -> body
      _other -> content
    end
  end

  defp fixture_paths do
    Path.wildcard(Path.join(@fixtures_dir, "**/*.{md,yml,yaml}"))
    |> Enum.map(&Path.relative_to(&1, @fixtures_dir))
    |> Enum.sort()
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

  defp compare_engines_and_report(rel_path, values, opts) do
    body = load_fixture_body(rel_path)
    opts = Keyword.merge([engine: BbMustache], opts)

    result_bb = CommBus.Template.render(body, values, opts)
    result_ex = CommBus.Template.render(body, values, Keyword.put(opts, :engine, ExMustache))

    case {result_bb, result_ex} do
      {{:ok, %RenderResult{content: content_bb}}, {:ok, %RenderResult{content: content_ex}}} ->
        if content_bb != content_ex do
          IO.puts("\n[template diff] #{rel_path}")
          print_diff(content_bb, content_ex)
        end

      {error_bb, error_ex} ->
        IO.puts("\n[template error] #{rel_path}")
        IO.inspect(error_bb, label: "bbmustache")
        IO.inspect(error_ex, label: "ex_mustache")
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

  test "loads prompt with frontmatter" do
    path = Path.join(@fixtures_dir, "devman/test_hello.md")

    assert {:ok, prompt} = Loader.load_prompt_file(path)
    assert prompt.name == "test_hello"
    assert prompt.description == "A simple test prompt"
    assert prompt.variables == ["name"]
    assert String.contains?(prompt.body, "Hello")
  end

  test "loads human prompt with slug frontmatter" do
    path = Path.join(@fixtures_dir, "human/alf/classifier.md")

    assert {:ok, prompt} =
             Loader.load_prompt_file(path,
               schema: :human,
               root: Path.join(@fixtures_dir, "human/alf")
             )

    assert prompt.slug == "alf/classifier"
    assert is_binary(prompt.body)
  end

  test "validates prompt variables consistency" do
    frontmatter = %{"name" => "sample", "description" => "desc", "variables" => ["name"]}
    body = "Hello {{name}} {{extra}}"

    assert {:error, [error | _]} = CommBus.Template.Validator.validate_prompt(frontmatter, body)
    assert %ValidationError{} = error
  end

  test "validates prompt struct with partials" do
    prompt = %Prompt{
      name: "sample",
      description: "desc",
      variables: ["name"],
      body: "Hello {{name}} {{> partial_one}}"
    }

    assert {:ok, %ValidationResult{} = result} =
             CommBus.Template.Validator.validate_prompt_struct(prompt, %{"name" => "Ada"},
               partials: %{"partial_one" => "OK"}
             )

    assert result.variables_required == ["name"]
    assert result.partials_required == ["partial_one"]
  end

  test "frontmatter parsing fails without delimiters" do
    assert {:error, [error | _]} = Loader.parse_frontmatter("No frontmatter")
    assert %ValidationError{} = error
  end

  test "prompts render with overrides" do
    {:ok, _pid} = CommBus.Prompts.OverrideStore.Memory.start_link(name: :override_store_test)
    Application.put_env(:comm_bus, :prompt_override_store, CommBus.Prompts.OverrideStore.Memory)

    on_exit(fn ->
      Application.delete_env(:comm_bus, :prompt_override_store)
    end)

    CommBus.Prompts.load_from_disk!(
      root: Path.join(@fixtures_dir, "devman/prompts"),
      schema: :devman
    )

    {:ok, _} =
      CommBus.Prompts.OverrideStore.Memory.create_override(%{
        slug: "test_hello",
        content: "Hi {{name}}",
        name: :override_store_test
      })

    rendered =
      CommBus.Prompts.render!("test_hello", %{"name" => "Ada"},
        name: :override_store_test,
        strict_mode: false
      )

    assert rendered == "Hi Ada"
  end
end
