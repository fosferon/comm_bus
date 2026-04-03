defmodule CommBus.Semantic.SimpleAdapter do
  @moduledoc """
  Default semantic adapter that scores similarity using token overlap (Jaccard index).
  """

  @behaviour CommBus.Semantic.Adapter

  @doc """
  Computes semantic similarity between a hint string and a text string using
  Jaccard index over tokenized word sets.

  ## Parameters

    - `_entry` — The entry struct (unused by this adapter).
    - `hint` — The keyword or hint string.
    - `text` — The message text to compare against.
    - `_opts` — Options (unused by this adapter).

  ## Returns

  A float between 0.0 and 1.0 representing the token set overlap.
  """
  @impl true
  def similarity(_entry, hint, text, _opts) do
    hint_tokens = tokenize(hint)
    text_tokens = tokenize(text)

    if hint_tokens == [] or text_tokens == [] do
      0.0
    else
      hint_set = MapSet.new(hint_tokens)
      text_set = MapSet.new(text_tokens)

      intersection = MapSet.size(MapSet.intersection(hint_set, text_set))
      union = MapSet.size(MapSet.union(hint_set, text_set))

      if union == 0 do
        0.0
      else
        intersection / union
      end
    end
  end

  defp tokenize(text) do
    text
    |> String.downcase()
    |> (fn value -> Regex.scan(~r/[[:alnum:]]+/u, value) end).()
    |> List.flatten()
  end
end
