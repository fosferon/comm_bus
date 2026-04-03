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

  @doc """
  Counts the number of tokens in the given text string using the configured
  tokenizer backend.

  ## Parameters

    - `text` — The text string to tokenize.
    - `opts` — Keyword options; `:tokenizer` overrides the configured backend.

  ## Returns

  A non-negative integer representing the token count.
  """
  @spec token_count(String.t(), keyword()) :: non_neg_integer()
  def token_count(text, opts \\ []) when is_binary(text) do
    tokenizer(opts).count_tokens(text, opts)
  end

  @doc """
  Counts the number of tokens in a message, including role overhead.

  ## Parameters

    - `message` — A `%CommBus.Message{}` struct.
    - `opts` — Keyword options; `:tokenizer` overrides the configured backend.

  ## Returns

  A non-negative integer representing the total token count for the message.
  """
  @spec message_count(Message.t(), keyword()) :: non_neg_integer()
  def message_count(%Message{} = message, opts \\ []) do
    tokenizer(opts).count_message(message, opts)
  end

  @doc """
  Fills in the `token_count` field of an entry by counting tokens in its content.

  If the entry already has a non-nil `token_count`, it is returned unchanged.

  ## Parameters

    - `entry` — A `%CommBus.Entry{}` struct.
    - `opts` — Keyword options forwarded to the tokenizer backend.

  ## Returns

  The entry with `token_count` populated.
  """
  @spec annotate_entry(Entry.t(), keyword()) :: Entry.t()
  def annotate_entry(entry, opts \\ [])

  def annotate_entry(%Entry{token_count: nil} = entry, opts) do
    %{entry | token_count: token_count(entry.content, opts)}
  end

  def annotate_entry(%Entry{} = entry, _opts), do: entry

  @doc """
  Annotates a list of entries with token counts by calling `annotate_entry/2`
  on each entry.

  ## Parameters

    - `entries` — List of `%CommBus.Entry{}` structs.
    - `opts` — Keyword options forwarded to the tokenizer backend.

  ## Returns

  A list of entries with `token_count` fields populated.
  """
  @spec annotate_entries([Entry.t()], keyword()) :: [Entry.t()]
  def annotate_entries(entries, opts \\ []) do
    Enum.map(entries, &annotate_entry(&1, opts))
  end

  @doc """
  Returns the tokenizer module resolved from options or application config.

  Checks, in order: the `:tokenizer` key in `opts`, the `:tokenizer` application
  env for `:comm_bus`, and falls back to `CommBus.Tokenizer.Simple`.

  ## Parameters

    - `opts` — Keyword options; `:tokenizer` overrides the configured backend.

  ## Returns

  The tokenizer module (an atom implementing the `CommBus.Tokenizer` behaviour).
  """
  @spec tokenizer(keyword()) :: module()
  def tokenizer(opts \\ []) do
    Keyword.get(opts, :tokenizer) ||
      Application.get_env(:comm_bus, :tokenizer, CommBus.Tokenizer.Simple)
  end
end
