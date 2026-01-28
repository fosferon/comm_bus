defmodule CommBus.Assembler do
  @moduledoc "Prompt assembly with injected context."

  alias CommBus.{Context, Conversation, Entry}

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
