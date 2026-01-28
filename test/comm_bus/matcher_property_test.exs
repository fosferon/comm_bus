defmodule CommBus.MatcherPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias CommBus.{Entry, Matcher, Message}

  test "match scores stay within [0, 1]" do
    check all(
            entry <- random_entry(),
            messages <- random_messages()
          ) do
      {results, _ctx} = Matcher.match_entries(messages, [entry])

      Enum.each(results, fn result ->
        assert result.score >= 0.0
        assert result.score <= 1.0
      end)
    end
  end

  test "entries hitting all keywords reach a perfect score" do
    check all(
            keywords <- keyword_list(),
            match_mode <- StreamData.member_of([:any, :all])
          ) do
      entry = %Entry{
        content: "methodology",
        keywords: keywords,
        match_mode: match_mode,
        mode: :triggered
      }

      # ensure every keyword appears at least once in the conversation
      conversation_text = Enum.join(keywords ++ ["extra context"], " ")
      messages = [%Message{role: :user, content: conversation_text}]

      {results, _ctx} = Matcher.match_entries(messages, [entry])

      assert [%{score: score}] = results
      assert_in_delta(score, 1.0, 1.0e-6)
    end
  end

  defp random_entry do
    keywords_gen = StreamData.one_of([keyword_list(), StreamData.constant([])])
    priority_gen = StreamData.integer(0..10)
    weight_gen = StreamData.integer(0..5)
    match_mode_gen = StreamData.member_of([:any, :all])

    StreamData.map(
      StreamData.tuple({keywords_gen, priority_gen, weight_gen, match_mode_gen}),
      fn {keywords, priority, weight, match_mode} ->
        %Entry{
          content: "entry",
          keywords: keywords,
          priority: priority,
          weight: weight,
          mode: :triggered,
          match_mode: match_mode
        }
      end
    )
  end

  defp random_messages do
    StreamData.list_of(
      StreamData.map(random_text(), fn text ->
        %Message{role: :user, content: text}
      end),
      min_length: 1,
      max_length: 5
    )
  end

  defp keyword_list do
    StreamData.uniq_list_of(random_keyword(), min_length: 1, max_length: 4)
  end

  defp random_keyword do
    StreamData.map(random_text(), &String.trim/1)
  end

  defp random_text do
    StreamData.string(:alphanumeric, min_length: 3, max_length: 12)
  end
end
