defmodule CommBus.Semantic.SimpleAdapter do
  @moduledoc """
  Default semantic adapter that scores similarity using token overlap (Jaccard index).
  """

  @behaviour CommBus.Semantic.Adapter

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
