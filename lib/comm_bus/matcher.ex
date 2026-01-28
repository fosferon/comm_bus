defmodule CommBus.Matcher do
  @moduledoc "Keyword, fuzzy, and semantic matching for triggered entries with diagnostics."

  alias CommBus.{Entry, Message, Semantic}

  defmodule MatchResult do
    @moduledoc "Match diagnostics for a given entry."
    defstruct entry: nil,
              score: 0.0,
              matched_keywords: [],
              messages_used: [],
              reasons: []
  end

  @spec scan_triggers([Message.t()], [Entry.t()], keyword()) :: [Entry.t()]
  def scan_triggers(messages, entries, opts \\ []) do
    {results, _info} = match_entries(messages, entries, opts)
    Enum.map(results, & &1.entry)
  end

  @spec match_entries([Message.t()], [Entry.t()], keyword()) :: {[MatchResult.t()], map()}
  def match_entries(messages, entries, opts \\ []) do
    scan_depth = Keyword.get(opts, :scan_depth, length(messages))
    recency_decay = Keyword.get(opts, :recency_decay, 0.9)
    idf_weights = compute_idf(entries)
    semantic_adapter = Semantic.adapter(opts)

    window = Enum.take(messages, -scan_depth)
    texts = Enum.map(window, & &1.content)
    injection_history = build_injection_history(window)

    {results, skipped} =
      entries
      |> Enum.reduce({[], []}, fn entry, {matches, skipped} ->
        cond do
          not entry.enabled ->
            {matches, [skip(entry, :disabled) | skipped]}

          true ->
            entry_texts = apply_entry_scan_depth(entry, texts)

            with :ok <- cooldown_status(entry, injection_history),
                 :ok <- negative_keyword_status(entry, entry_texts),
                 true <- match_entry?(entry, entry_texts, semantic_adapter, opts) do
              result =
                build_result(
                  entry,
                  entry_texts,
                  recency_decay,
                  idf_weights,
                  semantic_adapter,
                  opts
                )

              if passes_threshold?(result) do
                {[result | matches], skipped}
              else
                details = %{score: result.score, threshold: entry.match_threshold || 0.0}
                {matches, [skip(entry, :below_threshold, details) | skipped]}
              end
            else
              {:blocked, reason, details} ->
                {matches, [skip(entry, reason, details) | skipped]}

              false ->
                {matches, [skip(entry, :no_match) | skipped]}
            end
        end
      end)

    results = Enum.reverse(results)
    skipped = Enum.reverse(skipped)

    {results,
     %{
       messages: window,
       injection_history: injection_history,
       skipped_entries: skipped
     }}
  end

  defp build_result(%Entry{mode: :constant} = entry, _texts, _decay, _idf, _adapter, _opts) do
    %MatchResult{entry: entry, score: 1.0, reasons: [%{type: :constant}]}
  end

  defp build_result(entry, texts, decay, idf_weights, adapter, opts) do
    matches = keyword_hits(entry, texts, decay, idf_weights, adapter, opts)
    score = compute_score(entry, matches)

    %MatchResult{
      entry: entry,
      score: score,
      matched_keywords: Enum.map(matches, & &1.keyword),
      messages_used: Enum.map(matches, & &1.message_index),
      reasons: Enum.map(matches, &reason_from_match/1)
    }
  end

  defp match_entry?(%Entry{mode: :constant}, _texts, _adapter, _opts), do: true

  defp match_entry?(entry, texts, adapter, opts) do
    terms = match_terms(entry)

    cond do
      terms == [] -> false
      entry.match_mode == :all -> Enum.all?(terms, &match_term?(entry, &1, texts, adapter, opts))
      true -> Enum.any?(terms, &match_term?(entry, &1, texts, adapter, opts))
    end
  end

  defp match_term?(entry, term, texts, adapter, opts) do
    Enum.any?(texts, fn text -> match_detail(entry, text, term, adapter, opts) end)
  end

  defp keyword_hits(entry, texts, decay, idf_weights, adapter, opts) do
    total = length(texts)
    terms = match_terms(entry)

    terms
    |> Enum.flat_map(fn term ->
      texts
      |> Enum.with_index()
      |> Enum.reduce([], fn {text, idx}, acc ->
        case match_detail(entry, text, term, adapter, opts) do
          nil ->
            acc

          %{match_type: match_type, similarity: similarity} ->
            turns_ago = recency_turns_ago(total, idx)
            idf = idf_for_term(entry, term, idf_weights)
            weight = match_weight(term, turns_ago, decay, idf, match_type, similarity)

            [
              %{
                keyword: term,
                message_index: idx,
                turns_ago: turns_ago,
                weight: weight,
                match_type: match_type,
                similarity: similarity,
                idf: idf
              }
              | acc
            ]
        end
      end)
      |> Enum.sort_by(& &1.weight, :desc)
      |> Enum.take(1)
    end)
  end

  defp compute_score(%Entry{mode: :constant}, _matches), do: 1.0

  defp compute_score(entry, matches) do
    keyword_count = match_term_count(entry)
    weight_sum = Enum.reduce(matches, 0.0, fn match, acc -> acc + match.weight end)

    coverage = matches |> Enum.map(& &1.keyword) |> Enum.uniq() |> length()

    base =
      case entry.match_mode do
        :all -> if coverage == keyword_count, do: weight_sum, else: 0.0
        :any -> weight_sum
      end

    (base / keyword_count) |> min(1.0)
  end

  defp passes_threshold?(%MatchResult{entry: entry, score: score}) do
    threshold = entry.match_threshold || 0.0
    score >= threshold
  end

  defp apply_entry_scan_depth(%Entry{scan_depth: nil}, texts), do: texts

  defp apply_entry_scan_depth(%Entry{scan_depth: depth}, texts)
       when is_integer(depth) and depth > 0 do
    Enum.take(texts, -min(depth, length(texts)))
  end

  defp cooldown_status(%Entry{cooldown_turns: nil}, _history), do: :ok
  defp cooldown_status(%Entry{id: nil}, _history), do: :ok

  defp cooldown_status(entry, history) do
    turns_ago = Map.get(history, entry.id)

    if is_integer(turns_ago) and turns_ago < entry.cooldown_turns do
      remaining = entry.cooldown_turns - turns_ago
      {:blocked, :cooldown, %{turns_ago: turns_ago, remaining: remaining}}
    else
      :ok
    end
  end

  defp build_injection_history(messages) do
    messages
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {message, idx}, acc ->
      message.metadata
      |> Map.get(:comm_bus_entries, [])
      |> List.wrap()
      |> Enum.reduce(acc, fn entry_id, acc_inner -> Map.put_new(acc_inner, entry_id, idx) end)
    end)
  end

  defp recency_turns_ago(total, idx) do
    max(total - idx - 1, 0)
  end

  defp match_weight(_keyword, turns_ago, decay, idf_weight, match_type, similarity) do
    base =
      case match_type do
        :wildcard -> 0.7
        :fuzzy -> similarity
        :semantic -> similarity
        _ -> 1.0
      end

    recency = :math.pow(decay, turns_ago)
    base * recency * idf_weight
  end

  defp wildcard_term?(keyword), do: String.ends_with?(keyword, "*")

  defp reason_from_match(match) do
    %{
      type: :keyword,
      keyword: match.keyword,
      message_index: match.message_index,
      turns_ago: match.turns_ago,
      weight: match.weight,
      match_type: match.match_type,
      similarity: match.similarity,
      idf: match.idf
    }
  end

  defp skip(entry, reason, details \\ %{}) do
    %{entry: entry, reason: reason, details: details}
  end

  defp match_detail(entry, text, keyword, adapter, opts) do
    keyword = String.trim(keyword)

    cond do
      keyword == "" ->
        nil

      entry.match_strategy == :fuzzy ->
        fuzzy_match_detail(text, keyword, entry)

      entry.match_strategy == :semantic ->
        semantic_match_detail(entry, keyword, text, adapter, opts)

      true ->
        exact_match_detail(text, keyword)
    end
  end

  defp exact_match_detail(text, keyword) do
    cond do
      String.contains?(keyword, " ") ->
        if String.contains?(String.downcase(text), String.downcase(keyword)) do
          %{match_type: :exact, similarity: 1.0}
        end

      wildcard_term?(keyword) ->
        prefix = String.trim_trailing(keyword, "*")

        if prefix != "" and Regex.match?(~r/\b#{Regex.escape(prefix)}/i, text) do
          %{match_type: :wildcard, similarity: 1.0}
        end

      true ->
        if Regex.match?(~r/\b#{Regex.escape(keyword)}\b/i, text) do
          %{match_type: :exact, similarity: 1.0}
        end
    end
  end

  defp fuzzy_match_detail(text, keyword, entry) do
    threshold = entry.fuzzy_threshold || 0.85
    similarity = fuzzy_similarity(text, keyword)

    if similarity >= threshold do
      %{match_type: :fuzzy, similarity: similarity}
    end
  end

  defp semantic_match_detail(entry, hint, text, adapter, opts) do
    threshold = entry.semantic_threshold || 0.75

    similarity =
      adapter.similarity(entry, hint, text, opts)
      |> clamp_similarity()

    if similarity >= threshold do
      %{match_type: :semantic, similarity: similarity}
    end
  end

  defp clamp_similarity(value) when is_number(value) do
    value |> max(0.0) |> min(1.0)
  end

  defp clamp_similarity(_), do: 0.0

  defp fuzzy_similarity(text, keyword) do
    tokens = tokenize(text)
    keyword_tokens = tokenize(keyword)

    cond do
      tokens == [] or keyword_tokens == [] ->
        0.0

      true ->
        keyword_string = Enum.join(keyword_tokens, " ")
        max_window = max(length(keyword_tokens), 1)
        candidates = fuzzy_candidates(tokens, max_window)

        [Enum.join(tokens, " ") | candidates]
        |> Enum.reduce(0.0, fn segment, best ->
          similarity = String.jaro_distance(keyword_string, segment)
          max(best, similarity)
        end)
    end
  end

  defp fuzzy_candidates(tokens, max_window) do
    len = length(tokens)
    max_window = min(max_window, max(len, 1))

    for window <- 1..max_window,
        start <- 0..max(len - window, 0) do
      tokens |> Enum.slice(start, window) |> Enum.join(" ")
    end
  end

  defp tokenize(text) do
    lowercase = String.downcase(text)
    matches = Regex.scan(~r/[[:alnum:]]+/u, lowercase)
    List.flatten(matches)
  end

  defp compute_idf(entries) do
    enabled_entries = Enum.filter(entries, & &1.enabled)
    total = max(length(enabled_entries), 1)

    doc_counts =
      enabled_entries
      |> Enum.reduce(%{}, fn entry, acc ->
        entry.keywords
        |> Enum.map(&normalize_keyword/1)
        |> Enum.uniq()
        |> Enum.reduce(acc, fn keyword, inner -> Map.update(inner, keyword, 1, &(&1 + 1)) end)
      end)

    Enum.reduce(doc_counts, %{}, fn {keyword, freq}, acc ->
      weight = :math.log((total + 1) / (freq + 1)) + 1.0
      Map.put(acc, keyword, weight)
    end)
  end

  defp normalize_keyword(keyword) do
    keyword
    |> String.trim()
    |> String.downcase()
  end

  defp negative_keyword_status(%Entry{exclude_keywords: []}, _texts), do: :ok

  defp negative_keyword_status(entry, texts) do
    entry.exclude_keywords
    |> Enum.reject(&(&1 |> String.trim() == ""))
    |> Enum.reduce_while(:ok, fn keyword, _acc ->
      case find_negative_hit(texts, keyword) do
        nil ->
          {:cont, :ok}

        {idx, matched} ->
          details = %{keyword: keyword, message_index: idx, text: matched}
          {:halt, {:blocked, :negative_keyword, details}}
      end
    end)
  end

  defp find_negative_hit(texts, keyword) do
    texts
    |> Enum.with_index()
    |> Enum.find(fn {text, _idx} -> negative_match?(text, keyword) end)
  end

  defp negative_match?(text, keyword) do
    term = String.trim(keyword)

    cond do
      term == "" ->
        false

      String.contains?(term, " ") ->
        String.contains?(String.downcase(text), String.downcase(term))

      wildcard_term?(term) ->
        prefix = String.trim_trailing(term, "*")
        prefix != "" and Regex.match?(~r/\b#{Regex.escape(prefix)}/i, text)

      true ->
        Regex.match?(~r/\b#{Regex.escape(term)}\b/i, text)
    end
  end

  defp match_terms(%Entry{match_strategy: :semantic} = entry) do
    cond do
      entry.semantic_hints != [] -> entry.semantic_hints
      entry.keywords != [] -> entry.keywords
      String.trim(entry.content) != "" -> [entry.content]
      true -> []
    end
  end

  defp match_terms(entry), do: entry.keywords

  defp match_term_count(entry) do
    entry
    |> match_terms()
    |> length()
    |> max(1)
  end

  defp idf_for_term(%Entry{match_strategy: :semantic}, _term, _weights), do: 1.0

  defp idf_for_term(_entry, term, weights) do
    Map.get(weights, normalize_keyword(term), 1.0)
  end
end
