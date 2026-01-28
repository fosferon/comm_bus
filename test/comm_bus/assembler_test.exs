defmodule CommBus.AssemblerTest do
  use ExUnit.Case, async: true

  alias CommBus.{Assembler, Conversation, Entry, Message}

  test "includes match diagnostics in assembler result" do
    conversation = %Conversation{
      messages: [%Message{role: :user, content: "auth help"}]
    }

    entries = [
      %Entry{id: 1, mode: :triggered, keywords: ["auth"], enabled: true}
    ]

    result = Assembler.assemble_prompt(conversation, entries)

    [%CommBus.Matcher.MatchResult{entry: %Entry{id: 1}}] = result.match_diagnostics
    assert result.match_context[:messages] != nil
  end
end
