defmodule CommBus.Tokenizer.Simple do
  @moduledoc """
  Fallback tokenizer using a heuristic character/word based approximation.

  Roughly mirrors GPT tokenization by counting word boundaries and punctuation.
  """

  @behaviour CommBus.Tokenizer

  alias CommBus.Message

  @doc """
  Estimates the token count of a text string using a heuristic word-and-punctuation
  scan. Splits on word boundaries and counts each alphanumeric run and punctuation
  character as one token, roughly approximating GPT tokenization.

  ## Parameters

    - `text` — The text string to count tokens for.
    - `_opts` — Ignored; present for callback conformance.

  ## Returns

  A non-negative integer token count estimate.
  """
  @impl true
  def count_tokens(text, _opts) when is_binary(text) do
    text
    |> String.trim()
    |> case do
      "" ->
        0

      trimmed ->
        words = Regex.scan(~r/[[:alnum:]]+|[^\s[:alnum:]]/, trimmed)
        length(words)
    end
  end

  @doc """
  Counts tokens for a conversation message by summing the content token count
  and a fixed role-based overhead (2 tokens for most roles, 4 for tool messages).

  ## Parameters

    - `message` — A `%CommBus.Message{}` struct.
    - `opts` — Forwarded to `count_tokens/2`.

  ## Returns

  A non-negative integer representing the estimated token count.
  """
  @impl true
  def count_message(%Message{} = message, opts) do
    count_tokens(message.content, opts) + role_overhead(message.role)
  end

  defp role_overhead(:system), do: 2
  defp role_overhead(:user), do: 2
  defp role_overhead(:assistant), do: 2
  defp role_overhead(:tool), do: 4
  defp role_overhead(_), do: 2
end
