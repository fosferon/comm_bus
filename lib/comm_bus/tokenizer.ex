defmodule CommBus.Tokenizer do
  @moduledoc """
  Token counting façade with pluggable backends.

  Configure with:

      config :comm_bus, :tokenizer, CommBus.Tokenizer.Simple

  or supply `tokenizer: MyTokenizer` in function opts.
  """

  alias CommBus.{Entry, Message}

  @callback count_tokens(String.t(), keyword()) :: non_neg_integer()
  @callback count_message(Message.t(), keyword()) :: non_neg_integer()

  @spec token_count(String.t(), keyword()) :: non_neg_integer()
  def token_count(text, opts \\ []) when is_binary(text) do
    tokenizer(opts).count_tokens(text, opts)
  end

  @spec message_count(Message.t(), keyword()) :: non_neg_integer()
  def message_count(%Message{} = message, opts \\ []) do
    tokenizer(opts).count_message(message, opts)
  end

  @spec annotate_entry(Entry.t(), keyword()) :: Entry.t()
  def annotate_entry(entry, opts \\ [])

  def annotate_entry(%Entry{token_count: nil} = entry, opts) do
    %{entry | token_count: token_count(entry.content, opts)}
  end

  def annotate_entry(%Entry{} = entry, _opts), do: entry

  @spec annotate_entries([Entry.t()], keyword()) :: [Entry.t()]
  def annotate_entries(entries, opts \\ []) do
    Enum.map(entries, &annotate_entry(&1, opts))
  end

  @spec tokenizer(keyword()) :: module()
  def tokenizer(opts \\ []) do
    Keyword.get(opts, :tokenizer) ||
      Application.get_env(:comm_bus, :tokenizer, CommBus.Tokenizer.Simple)
  end
end
