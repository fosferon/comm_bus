defmodule CommBus.Budget do
  @moduledoc "Token budget management."

  alias CommBus.Entry

  @doc """
  Selects entries that fit within a token budget using priority-based greedy selection.

  Entries are sorted by `(priority, weight, id)` in descending order, then
  accumulated until the token limit is reached. Entries whose `token_count`
  would exceed the remaining budget are skipped.

  ## Parameters

    - `entries` — List of `%CommBus.Entry{}` structs with `token_count` populated.
    - `limit` — Maximum number of tokens allowed.

  ## Returns

  A list of `%CommBus.Entry{}` structs that fit within the budget, preserving
  the priority-based selection order.
  """
  @spec fit_budget([Entry.t()], non_neg_integer()) :: [Entry.t()]
  def fit_budget(entries, limit) do
    entries
    |> Enum.sort_by(&sort_key/1, :desc)
    |> Enum.reduce({[], 0}, fn entry, {kept, total} ->
      entry_tokens = entry.token_count || 0

      if total + entry_tokens <= limit do
        {[entry | kept], total + entry_tokens}
      else
        {kept, total}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp sort_key(%Entry{} = entry) do
    {entry.priority, entry.weight, entry.id || entry.content}
  end
end
