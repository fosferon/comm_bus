defmodule CommBus.Tokenizer.SimpleTest do
  use ExUnit.Case, async: true

  alias CommBus.{Message, Tokenizer}

  test "counts tokens using heuristic" do
    assert Tokenizer.token_count("Hello world") == 2
    assert Tokenizer.token_count("Hello, world!") == 4
    assert Tokenizer.token_count("") == 0
  end

  test "counts message tokens with role overhead" do
    message = %Message{role: :user, content: "Need help"}
    assert Tokenizer.message_count(message) == 4
  end

  test "annotates entries" do
    entry = %CommBus.Entry{content: "System rules", token_count: nil}
    annotated = Tokenizer.annotate_entry(entry)
    assert annotated.token_count > 0
  end
end
