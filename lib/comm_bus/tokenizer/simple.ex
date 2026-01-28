defmodule CommBus.Tokenizer.Simple do
  @moduledoc """
  Fallback tokenizer using a heuristic character/word based approximation.

  Roughly mirrors GPT tokenization by counting word boundaries and punctuation.
  """

  @behaviour CommBus.Tokenizer

  alias CommBus.Message

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
