# CommBus

Conversational context assembly for LLM interactions. CommBus injects
keyword-triggered entries into prompts while respecting token budgets.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `comm_bus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:comm_bus, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/comm_bus>.

## Quick start

```elixir
alias CommBus.{Assembler, Conversation, Entry, Message}

conversation = %Conversation{
  messages: [
    %Message{role: :user, content: "Need help with auth."}
  ]
}

entries = [
  %Entry{id: 1, mode: :constant, section: :system, token_count: 5, content: "Rules."},
  %Entry{id: 2, keywords: ["auth"], section: :pre_history, token_count: 3, content: "Auth info."}
]

Assembler.assemble_prompt(conversation, entries, budget: %{sections: %{system: 5, pre_history: 3}})
```
