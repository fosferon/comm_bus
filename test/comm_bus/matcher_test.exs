defmodule CommBus.MatcherTest do
  use ExUnit.Case, async: true

  alias CommBus.{Entry, Matcher, Message}

  test "returns diagnostics for matches" do
    messages = [%Message{role: :user, content: "Need auth help"}]
    entries = [%Entry{id: 1, keywords: ["auth"], enabled: true}]

    {results, _} = Matcher.match_entries(messages, entries)
    [result] = results

    assert result.entry.id == 1
    assert result.score == 1.0
    assert result.matched_keywords == ["auth"]
  end

  test "respects per-entry scan depth" do
    messages = [
      %Message{role: :user, content: "older context"},
      %Message{role: :user, content: "latest"}
    ]

    entries = [
      %Entry{id: 1, keywords: ["older"], enabled: true, scan_depth: 1}
    ]

    {results, _} = Matcher.match_entries(messages, entries)
    assert results == []
  end

  test "cooldown blocks entries recently injected" do
    messages = [
      %Message{role: :assistant, content: "previous", metadata: %{comm_bus_entries: [1]}},
      %Message{role: :user, content: "need auth"}
    ]

    entries = [
      %Entry{id: 1, keywords: ["auth"], enabled: true, cooldown_turns: 2}
    ]

    {results, _} = Matcher.match_entries(messages, entries)
    assert results == []
  end

  test "recency weighting reduces score for older matches" do
    messages = [
      %Message{role: :user, content: "old auth"},
      %Message{role: :user, content: "latest"}
    ]

    strict = %Entry{
      id: 1,
      keywords: ["auth"],
      enabled: true,
      match_threshold: 0.6
    }

    loose = %{strict | id: 2, match_threshold: 0.4}

    {strict_results, _} = Matcher.match_entries(messages, [strict], recency_decay: 0.5)
    assert strict_results == []

    {[loose_result], _} = Matcher.match_entries(messages, [loose], recency_decay: 0.5)
    assert_in_delta loose_result.score, :math.pow(0.5, 1), 0.001
  end

  test "wildcard matches apply penalty" do
    messages = [%Message{role: :user, content: "accounts payable"}]
    entry = %Entry{id: 1, keywords: ["account*"], enabled: true}

    {[result], _} = Matcher.match_entries(messages, [entry], recency_decay: 1.0)
    assert_in_delta result.score, 0.7, 0.001
    assert %{match_type: :wildcard} = hd(result.reasons)
  end

  test "keyword rarity boosts score" do
    messages = [%Message{role: :user, content: "rare common"}]

    entries = [
      %Entry{id: 1, keywords: ["common"], enabled: true},
      %Entry{id: 2, keywords: ["common"], enabled: true},
      %Entry{id: 3, keywords: ["rare"], enabled: true}
    ]

    {results, _} = Matcher.match_entries(messages, entries, recency_decay: 1.0)
    reasons_by_entry = Map.new(results, fn result -> {result.entry.id, result.reasons} end)

    rare_idf = reasons_by_entry[3] |> hd() |> Map.fetch!(:idf)
    common_idf = reasons_by_entry[1] |> hd() |> Map.fetch!(:idf)

    assert rare_idf > common_idf
  end

  test "fuzzy matching respects threshold" do
    messages = [%Message{role: :user, content: "Need authorization"}]

    fuzzy_entry = %Entry{
      id: 1,
      keywords: ["authorisation"],
      enabled: true,
      match_strategy: :fuzzy,
      fuzzy_threshold: 0.8
    }

    strict_entry = %{fuzzy_entry | id: 2, fuzzy_threshold: 0.99}

    {[fuzzy_result], _} = Matcher.match_entries(messages, [fuzzy_entry])
    assert %{match_type: :fuzzy} = hd(fuzzy_result.reasons)
    assert fuzzy_result.score > 0.0

    {strict_results, _} = Matcher.match_entries(messages, [strict_entry])
    assert strict_results == []
  end

  test "negative keywords block otherwise matching entries" do
    messages = [%Message{role: :user, content: "auth please skip"}]

    entry = %Entry{
      id: 1,
      keywords: ["auth"],
      exclude_keywords: ["skip"],
      enabled: true
    }

    {results, _} = Matcher.match_entries(messages, [entry])
    assert results == []
  end

  test "semantic strategy matches via adapter" do
    messages = [%Message{role: :user, content: "Need to reset password now"}]

    entry = %Entry{
      id: 1,
      match_strategy: :semantic,
      semantic_hints: ["reset password"],
      semantic_threshold: 0.4,
      enabled: true
    }

    {[result], _} = Matcher.match_entries(messages, [entry])
    assert %{match_type: :semantic} = hd(result.reasons)
    assert result.score > 0.0
  end
end
