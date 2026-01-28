defmodule CommBus.Budget do
  @moduledoc "Token budget management."

  alias CommBus.Entry

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
