defmodule CommBus.Telemetry do
  @moduledoc """
  Helpers for consuming CommBus telemetry events and defining common metrics.
  """

  import Telemetry.Metrics

  @metrics_event [:comm_bus, :context, :metrics]
  @plan_stop_event [:comm_bus, :context, :plan, :stop]

  @doc "Event emitted after each plan with inclusion/budget measurements."
  @spec metrics_event() :: [atom()]
  def metrics_event, do: @metrics_event

  @doc "Telemetry span stop event for context planning."
  @spec plan_stop_event() :: [atom()]
  def plan_stop_event, do: @plan_stop_event

  @doc "Return Telemetry.Metrics definitions for common CommBus metrics."
  @spec metrics([atom()]) :: list()
  def metrics(prefix \\ [:comm_bus]) do
    [
      summary(metric_name(prefix, [:context, :metrics, :inclusion_rate]),
        event_name: @metrics_event,
        measurement: :inclusion_rate,
        unit: :ratio,
        tags: [:conversation_id]
      ),
      summary(metric_name(prefix, [:context, :metrics, :budget_waste]),
        event_name: @metrics_event,
        measurement: :budget_waste,
        unit: :token,
        tags: [:conversation_id]
      ),
      sum(metric_name(prefix, [:context, :metrics, :included]),
        event_name: @metrics_event,
        measurement: :included_count,
        tags: [:conversation_id]
      ),
      sum(metric_name(prefix, [:context, :metrics, :candidates]),
        event_name: @metrics_event,
        measurement: :candidate_count,
        tags: [:conversation_id]
      ),
      summary(metric_name(prefix, [:context, :plan, :duration]),
        event_name: @plan_stop_event,
        measurement: :duration,
        unit: {:native, :millisecond}
      )
    ]
  end

  defp metric_name(prefix, suffix) do
    prefix
    |> Enum.concat(suffix)
    |> Enum.join(".")
  end
end
