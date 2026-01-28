defmodule CommBus.BudgetPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias CommBus.{Budget, Entry}

  test "fit_budget never exceeds the requested limit" do
    check all(
            entries <- entry_list(),
            limit <- StreamData.integer(0..5_000)
          ) do
      kept = Budget.fit_budget(entries, limit)
      total_tokens = Enum.reduce(kept, 0, &(&2 + token_count(&1)))

      assert total_tokens <= limit
      assert Enum.all?(kept, &(&1 in entries))
    end
  end

  test "fit_budget returns all entries in priority order when limit is large enough" do
    check all(entries <- entry_list()) do
      total = Enum.reduce(entries, 0, &(&2 + token_count(&1)))
      limit = total + 100

      kept = Budget.fit_budget(entries, limit)
      assert kept == sort_by_priority(entries)
    end
  end

  defp entry_list do
    StreamData.list_of(entry_generator(), min_length: 0, max_length: 8)
  end

  defp entry_generator do
    priorities = StreamData.integer(-5..5)
    weights = StreamData.integer(-3..3)
    tokens = StreamData.integer(0..500)
    id = StreamData.integer(1..10_000)

    StreamData.map(
      StreamData.tuple({priorities, weights, tokens, id}),
      fn {priority, weight, token_count, id} ->
        %Entry{
          id: id,
          content: "entry-#{id}",
          priority: priority,
          weight: weight,
          token_count: token_count,
          keywords: ["kw#{id}"]
        }
      end
    )
  end

  defp token_count(%Entry{token_count: nil}), do: 0
  defp token_count(%Entry{token_count: value}), do: value

  defp sort_by_priority(entries) do
    Enum.sort_by(entries, &{&1.priority, &1.weight, &1.id || &1.content}, :desc)
  end
end
