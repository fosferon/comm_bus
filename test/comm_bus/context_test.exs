defmodule CommBus.ContextTest do
  use ExUnit.Case, async: true

  alias CommBus.{Context, Conversation, Entry, Message}

  test "plan returns exclusions and section usage" do
    conversation = %Conversation{
      id: "conv-1",
      messages: [%Message{role: :user, content: "Need onboarding help"}]
    }

    entries = [
      %Entry{id: 1, mode: :constant, section: :system, content: "Rules"},
      %Entry{id: 2, mode: :triggered, keywords: ["onboarding"], enabled: true},
      %Entry{id: 3, mode: :triggered, keywords: ["skip"], enabled: false}
    ]

    plan =
      Context.plan(conversation, entries,
        budget: %{
          plan: [total: 200, completion: 50, section_ratios: %{system: 0.5, history: 0.5}]
        }
      )

    assert %Context.Plan{} = plan

    assert Map.has_key?(plan.token_usage, :sections) or
             Map.has_key?(plan.token_usage, :total_budget)

    assert Enum.any?(plan.exclusions, &(&1.reason == :disabled))
    assert plan.sections[:history] == conversation.messages
  end

  test "emits telemetry events" do
    handler_id = "context-plan-telemetry"
    metrics_handler_id = "context-metrics-telemetry"

    :telemetry.attach_many(
      handler_id,
      [[:comm_bus, :context, :plan, :stop]],
      &__MODULE__.telemetry_handler/4,
      self()
    )

    :telemetry.attach_many(
      metrics_handler_id,
      [[:comm_bus, :context, :metrics]],
      &__MODULE__.telemetry_handler/4,
      self()
    )

    conversation = %Conversation{
      id: "conv-tele",
      messages: [%Message{role: :user, content: "Need auth"}]
    }

    entries = [%Entry{id: 1, mode: :triggered, keywords: ["auth"], enabled: true}]

    try do
      _plan = Context.plan(conversation, entries)

      assert_receive {:telemetry, [:comm_bus, :context, :plan, :stop], _measurements,
                      %{conversation_id: "conv-tele"} = metadata},
                     500

      assert metadata[:included_count] >= 0

      assert_receive {:telemetry, [:comm_bus, :context, :metrics], measurements,
                      %{conversation_id: "conv-tele"} = metrics_metadata},
                     500

      assert measurements[:inclusion_rate] >= 0
      assert metrics_metadata[:conversation_id] == "conv-tele"
    after
      :telemetry.detach(handler_id)
      :telemetry.detach(metrics_handler_id)
    end
  end

  def telemetry_handler(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end
end
