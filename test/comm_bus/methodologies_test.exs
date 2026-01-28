defmodule CommBus.MethodologiesTest do
  use ExUnit.Case, async: true

  alias CommBus.Methodologies

  @root Path.expand("config/comm_bus/methodologies", File.cwd!())

  setup do
    Methodologies.clear_cache!()
    :ok
  end

  test "loads methodologies from disk" do
    catalog = Methodologies.load_from_disk!(root: @root)
    assert Map.has_key?(catalog, "analysis/root_cause")

    %CommBus.Methodology{name: name, entries: entries} = catalog["analysis/root_cause"]
    assert name == "Root Cause Analysis"
    assert length(entries) == 2
  end

  test "resolves entries for a slug" do
    Methodologies.load_from_disk!(root: @root)

    entries = Methodologies.entries_for("analysis/root_cause")
    assert Enum.any?(entries, &(&1.id == "rca_guardrails"))
  end

  test "resolves a specific entry via slug reference" do
    Methodologies.load_from_disk!(root: @root)

    [entry] = Methodologies.entries_for("analysis/root_cause#rca_template")
    assert entry.id == "rca_template"
    assert entry.section == :pre_history
  end

  test "raises on invalid definitions" do
    tmp = tmp_dir()
    File.write!(Path.join(tmp, "invalid.yml"), "name: ''\nentries: []")

    assert_raise ArgumentError, fn ->
      Methodologies.load_from_disk!(root: tmp)
    end
  end

  defp tmp_dir do
    path = Path.join(System.tmp_dir!(), "commbus-methodologies-#{System.unique_integer()}")
    File.mkdir_p!(path)
    path
  end
end
