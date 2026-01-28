# CommBus

Elixir library for conversational context assembly in LLM interactions. Database-agnostic middleware that sits between applications and LLM providers, solving keyword-triggered context injection with token budget management.

## Quick Reference

```bash
mix deps.get          # Install dependencies
mix compile           # Compile project
mix test              # Run all tests
mix format            # Format code
mix docs              # Generate documentation
```

## Architecture

### Core Flow
```
Conversation + Entries → Assembler → Budget Fitting → Sectioned Packet
```

### Key Modules

| Module | Purpose |
|--------|---------|
| `CommBus` | Public API facade |
| `CommBus.Assembler` | Core prompt assembly orchestration |
| `CommBus.Matcher` | Keyword trigger detection (wildcards, phrases, word boundaries) |
| `CommBus.Budget` | Token constraint fitting (priority-based greedy selection) |
| `CommBus.Budget.Planner` | Section budget allocation (system 10%, pre_history 30%, history 40%, post_history 20%) |
| `CommBus.Tokenizer` | Pluggable token counting facade |
| `CommBus.Template.Engine` | Mustache template rendering (bbmustache default) |
| `CommBus.Template.Loader` | YAML frontmatter prompt file loading |
| `CommBus.Prompts` | Prompt catalog with persistent_term caching and overrides |
| `CommBus.Protocol.Pipeline` | ALF-based assembly pipeline |

### Data Structures

- **Entry** - Injectable context: `id`, `content`, `keywords`, `priority`, `weight`, `section`, `mode` (`:constant`/`:triggered`)
- **Message** - OpenAI-style: `role` (`:system`/`:user`/`:assistant`/`:tool`), `content`, `token_count`
- **Conversation** - Session state: `id`, `messages`, `depth`, `metadata`
- **Packet** - Assembly output: `messages`, `sections`, `included_entries`, `excluded_entries`, `token_usage`

### Storage Adapters

- `CommBus.Storage.InMemory` - Testing
- `CommBus.Storage.EctoAdapter` - Database via Ecto
- `CommBus.Storage.Devman` - DevMan-specific (SQLite)
- `CommBus.Storage.Human` - HuMan-specific (PostgreSQL)

## Project Structure

```
lib/comm_bus/
├── assembler.ex           # Core assembly logic
├── matcher.ex             # Keyword matching
├── budget.ex              # Budget fitting
├── budget/planner.ex      # Budget allocation
├── tokenizer/simple.ex    # Heuristic tokenizer
├── template/              # Template system
│   ├── engine/            # Mustache engines (bb_mustache, ex_mustache)
│   ├── loader.ex          # YAML frontmatter parsing
│   └── validator.ex       # Prompt validation
├── prompts/               # Prompt catalog
│   ├── runtime.ex         # Runtime management
│   └── watcher.ex         # File system watcher
├── protocol/              # LLM adapter pipeline
│   ├── pipeline.ex        # ALF pipeline
│   ├── packet.ex          # Canonical payload
│   └── llm_core_adapter.ex
└── storage/               # Storage adapters
    ├── in_memory.ex
    └── ecto_adapter.ex

test/fixtures/golden/      # Template test fixtures
  ├── devman/              # DevMan prompt fixtures
  └── human/               # HuMan prompt fixtures
```

## Configuration

```elixir
config :comm_bus,
  template_engine: CommBus.Template.Engine.BbMustache,  # or ExMustache
  tokenizer: CommBus.Tokenizer.Simple,
  prompt_root: Path.expand("config/comm_bus/prompts", File.cwd!()),
  prompt_override_store: CommBus.Prompts.OverrideStore.Noop
```

## Conventions

- Return tuples: `{:ok, value}` or `{:error, reason}`
- Use `@spec` type annotations on public functions
- Pipe operator for data transformations
- Pattern matching for control flow
- Entry sections: `:system`, `:pre_history`, `:history`, `:post_history`
- Entry modes: `:constant` (always inject) or `:triggered` (keyword-based)
- Match modes: `:any` (OR) or `:all` (AND) for keyword matching

## Testing

```bash
mix test                                    # All tests
mix test test/comm_bus_test.exs            # Main integration tests
mix test --cover                            # With coverage
mix comm_bus.compare_engines               # Compare Mustache engines
mix comm_bus.sync_fixtures                 # Sync test fixtures
```

Test fixtures in `test/fixtures/golden/` for template consistency testing.

## Dependencies

- **bbmustache** / **ex_mustache** - Template engines
- **yaml_elixir** - YAML frontmatter parsing
- **alf** - Pipeline framework
- **ecto** - Database abstraction (optional, for EctoAdapter)
- **file_system** - Prompt file watching
- **telemetry** - Observability

## Common Patterns

### Basic Assembly
```elixir
alias CommBus.{Assembler, Conversation, Entry, Message}

conversation = %Conversation{
  messages: [%Message{role: :user, content: "Need help with auth."}]
}

entries = [
  %Entry{id: 1, mode: :constant, section: :system, content: "System rules."},
  %Entry{id: 2, keywords: ["auth"], section: :pre_history, content: "Auth context."}
]

result = Assembler.assemble_prompt(conversation, entries, budget: %{sections: %{system: 100, pre_history: 200}})
```

### Template Rendering
```elixir
CommBus.render_template("Hello {{name}}!", %{name: "World"}, strict_mode: true)
```

### Prompt Loading
```elixir
{:ok, prompt} = CommBus.Template.Loader.load_prompt("path/to/prompt.md")
CommBus.Prompts.render(prompt.name, %{var: "value"})
```

## Related Projects

- **llm_core** - LLM provider abstraction (sits below CommBus)
- **DevMan** - CLI workflow orchestration (consumer)
- **HuMan** - Reasoning infrastructure (consumer)
