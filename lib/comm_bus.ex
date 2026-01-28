defmodule CommBus do
  @moduledoc """
  Conversational context assembly for LLM interactions.
  """

  alias CommBus.{Assembler, Entry, Message}

  @doc "Scan conversation history for entries that match keyword triggers."
  @spec scan_triggers([Message.t()], [Entry.t()], keyword()) :: [Entry.t()]
  def scan_triggers(messages, entries, opts \\ []) do
    CommBus.Matcher.scan_triggers(messages, entries, opts)
  end

  @doc "Fit entries within a token budget using priority ordering."
  @spec fit_budget([Entry.t()], non_neg_integer()) :: [Entry.t()]
  def fit_budget(entries, limit) do
    CommBus.Budget.fit_budget(entries, limit)
  end

  @doc "Assemble prompt sections with injected context entries."
  @spec assemble_prompt(CommBus.Conversation.t(), [Entry.t()], keyword()) :: map()
  def assemble_prompt(conversation, entries, opts \\ []) do
    Assembler.assemble_prompt(conversation, entries, opts)
  end

  @doc "Render a Mustache template with provided values."
  @spec resolve_placeholders(String.t(), map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def resolve_placeholders(template, values, opts \\ []) do
    case CommBus.Template.render(template, values, Keyword.put_new(opts, :strict_mode, false)) do
      {:ok, %CommBus.Template.RenderResult{content: content}} -> {:ok, content}
      {:error, error} -> {:error, error}
    end
  end

  @doc "Render a Mustache template with metadata."
  @spec render_template(String.t(), map(), keyword()) ::
          {:ok, CommBus.Template.RenderResult.t()} | {:error, CommBus.Template.RenderError.t()}
  def render_template(template, values, opts \\ []) do
    CommBus.Template.render(template, values, opts)
  end
end
