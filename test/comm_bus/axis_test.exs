defmodule CommBus.AxisTest do
  use ExUnit.Case, async: false

  alias CommBus.{Axis, Entry}

  # persistent_term is VM-global; reset for isolation.
  setup do
    Axis.reset()
    :ok
  end

  # --------------------------------------------------------------------------
  # declare / introspection
  # --------------------------------------------------------------------------

  test "declare registers an axis and exposes it via spec/1 and declared/0" do
    assert :ok == Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)

    assert {:ok, %{values: [:internal, :disclosed], default: :internal}} ==
             Axis.spec(:visibility)

    assert [:visibility] == Axis.declared()
  end

  test "declare accepts string axis name and string values/default (normalized to atoms)" do
    assert :ok ==
             Axis.declare("feasibility",
               values: ["proven", "speculative"],
               default: "speculative"
             )

    assert {:ok, %{values: [:proven, :speculative], default: :speculative}} ==
             Axis.spec("feasibility")

    assert [:feasibility] == Axis.declared()
  end

  test "declare is idempotent / overridable" do
    :ok = Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)
    :ok = Axis.declare(:visibility, values: [:internal, :disclosed, :masked], default: :masked)

    assert {:ok, %{values: [:internal, :disclosed, :masked], default: :masked}} =
             Axis.spec(:visibility)

    assert [:visibility] == Axis.declared()
  end

  test "declare preserves declaration order in declared/0" do
    :ok = Axis.declare(:visibility, values: [:a, :b], default: :a)
    :ok = Axis.declare(:feasibility, values: [:c, :d], default: :c)

    # declared/0 sorts for determinism; both axes present.
    assert [:feasibility, :visibility] == Axis.declared()
  end

  test "declare rejects missing or empty values" do
    assert {:error, :missing_values} == Axis.declare(:visibility, default: :internal)
    assert {:error, :empty_values} == Axis.declare(:visibility, values: [], default: :internal)
  end

  test "declare rejects missing default" do
    assert {:error, :missing_default} ==
             Axis.declare(:visibility, values: [:internal, :disclosed])
  end

  test "declare rejects default not in values" do
    assert {:error, {:default_not_in_values, :unknown}} ==
             Axis.declare(:visibility, values: [:internal, :disclosed], default: :unknown)
  end

  test "spec on unknown axis returns an error" do
    assert {:error, {:unknown_axis, :nope}} == Axis.spec(:nope)
  end

  test "delete removes a declaration" do
    :ok = Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)
    assert :ok == Axis.delete(:visibility)
    assert [] == Axis.declared()
    assert {:error, {:unknown_axis, :visibility}} == Axis.spec(:visibility)
  end

  test "reset clears all declarations" do
    :ok = Axis.declare(:visibility, values: [:a, :b], default: :a)
    :ok = Axis.declare(:feasibility, values: [:c, :d], default: :c)
    assert [:feasibility, :visibility] == Axis.declared()

    :ok = Axis.reset()
    assert [] == Axis.declared()
  end

  # --------------------------------------------------------------------------
  # get — resolution
  # --------------------------------------------------------------------------

  describe "get/2" do
    setup do
      Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)
      Axis.declare(:feasibility, values: [:proven, :speculative], default: :speculative)
      :ok
    end

    test "tagged entry: returns the declared value (atom metadata key + atom value)" do
      entry = %Entry{metadata: %{visibility: :disclosed}}
      assert {:ok, :disclosed} == Axis.get(entry, :visibility)
    end

    test "tagged entry: returns the declared value (string metadata key + string value, as from yml)" do
      entry = %Entry{metadata: %{"visibility" => "disclosed"}}
      assert {:ok, :disclosed} == Axis.get(entry, :visibility)
    end

    test "untagged entry: falls back to the declared default" do
      assert {:ok, :internal} == Axis.get(%Entry{}, :visibility)
      assert {:ok, :speculative} == Axis.get(%Entry{metadata: %{}}, :feasibility)
    end

    test "entry tagged on a different axis is untagged for this one (default fallback)" do
      entry = %Entry{metadata: %{feasibility: :proven}}
      assert {:ok, :internal} == Axis.get(entry, :visibility)
      assert {:ok, :proven} == Axis.get(entry, :feasibility)
    end

    test "two independent axes resolve independently (genericity)" do
      entry = %Entry{metadata: %{visibility: :disclosed, feasibility: :proven}}
      assert {:ok, :disclosed} == Axis.get(entry, :visibility)
      assert {:ok, :proven} == Axis.get(entry, :feasibility)
    end

    test "illegal stored value surfaces an error rather than coercing" do
      entry = %Entry{metadata: %{visibility: :top_secret}}
      assert {:error, {:invalid_value, :visibility, :top_secret}} == Axis.get(entry, :visibility)
    end

    test "illegal string stored value surfaces an error with the raw value" do
      entry = %Entry{metadata: %{"visibility" => "leaked"}}
      assert {:error, {:invalid_value, :visibility, "leaked"}} == Axis.get(entry, :visibility)
    end

    test "unknown axis returns an error" do
      assert {:error, {:unknown_axis, :sensitivity}} == Axis.get(%Entry{}, :sensitivity)
    end

    test "string axis name resolves the same as atom" do
      entry = %Entry{metadata: %{"visibility" => "disclosed"}}
      assert {:ok, :disclosed} == Axis.get(entry, "visibility")
    end
  end

  describe "get!/2" do
    setup do
      Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)
      :ok
    end

    test "returns the bare value on success" do
      assert :disclosed == Axis.get!(%Entry{metadata: %{visibility: :disclosed}}, :visibility)
      assert :internal == Axis.get!(%Entry{}, :visibility)
    end

    test "raises on unknown axis" do
      assert_raise ArgumentError, fn -> Axis.get!(%Entry{}, :sensitivity) end
    end

    test "raises on illegal stored value" do
      assert_raise ArgumentError, fn ->
        Axis.get!(%Entry{metadata: %{visibility: :leaked}}, :visibility)
      end
    end
  end

  # --------------------------------------------------------------------------
  # Layering rubric: the module carries no consumer vocabulary.
  # (This is a guard against semantic drift; it is about the *declared axis
  # names* not being baked in, not about words in the source.)
  # --------------------------------------------------------------------------

  test "no axes are declared by default — vocabularies belong to consumers" do
    # comm_bus ships the mechanism only. Fresh registry is empty.
    assert [] == Axis.declared()
  end
end
