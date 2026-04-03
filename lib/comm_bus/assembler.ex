defmodule CommBus.Assembler do
  @moduledoc "Prompt assembly with injected context."

  alias CommBus.{Context, Conversation, Entry}

  @doc """
  Assembles a prompt from the given conversation and context entries, applying
  keyword matching, budget fitting, and section allocation.

  ## Parameters

    - `conversation` — A `%CommBus.Conversation{}` with message history.
    - `entries` — List of `%CommBus.Entry{}` structs to consider for injection.
    - `opts` — Keyword options forwarded to `CommBus.Context.plan/3`, including
      `:budget`, `:scan_depth`, `:recency_decay`, and `:methodologies`.

  ## Returns

  A map with keys `:sections`, `:included_entries`, `:excluded_entries`,
  `:token_usage`, `:match_diagnostics`, and `:match_context`.
  """
  @spec assemble_prompt(Conversation.t(), [Entry.t()], keyword()) :: map()
  def assemble_prompt(%Conversation{} = conversation, entries, opts \\ []) do
    plan = Context.plan(conversation, entries, opts)

    %{
      sections: plan.sections,
      included_entries: plan.included_entries,
      excluded_entries: plan.excluded_entries,
      token_usage: plan.token_usage,
      match_diagnostics: plan.match_diagnostics,
      match_context: plan.match_context
    }
  end
end
