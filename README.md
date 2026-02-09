# CommBus

**Conversational context assembly for LLM interactions.** CommBus injects keyword-triggered entries into prompts while respecting token budgets, providing intelligent context management for your AI applications.

## Features

- **Keyword Matching** - Wildcard patterns (`auth*`), phrases (`"two words"`), word boundaries, and semantic similarity
- **Token Budget Management** - Priority-based greedy fitting with intelligent section allocation
- **Template Engine** - Mustache support (BbMustache/ExMustache) with YAML frontmatter parsing
- **Prompt Catalog** - Persistent_term caching with FileSystem watching for hot reloading
- **Storage Adapters** - In-memory and Ecto, with a behaviour for custom adapters
- **Methodologies** - YAML-based curated prompt packs for reusable workflows
- **Protocol Pipeline** - ALF-based assembly with llm_core integration
- **Mix Tasks** - CLI utilities for entry inspection, budget simulation, and testing
- **Telemetry Integration** - Built-in observability for assembly operations

## Installation

Add `comm_bus` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:comm_bus, git: "https://github.com/fosferon/comm_bus.git"}
  ]
end
```

> **Note:** CommBus is not yet published on Hex. Use the git dependency for now.

## Quick Start

### Basic Assembly

```elixir
alias CommBus.{Assembler, Conversation, Entry, Message}

# Define conversation
conversation = %Conversation{
  messages: [
    %Message{role: :user, content: "Need help with authentication."}
  ]
}

# Define context entries
entries = [
  # Constant entry - always included
  %Entry{
    id: "system-rules",
    mode: :constant,
    section: :system,
    token_count: 15,
    content: "You are a helpful assistant. Be concise and accurate.",
    priority: 100
  },

  # Triggered entry - only when keywords match
  %Entry{
    id: "auth-context",
    mode: :triggered,
    keywords: ["auth*", "login", "session"],
    section: :pre_history,
    token_count: 50,
    content: "Authentication system uses JWT tokens with 24h expiration...",
    priority: 80
  }
]

# Assemble with budget
result = Assembler.assemble_prompt(
  conversation,
  entries,
  budget: %{
    total: 1000,
    sections: %{
      system: 100,
      pre_history: 300,
      history: 400,
      post_history: 200
    }
  }
)

# Result contains sectioned messages ready for LLM
IO.inspect(result.messages)
IO.inspect(result.token_usage)
```

### Using Methodologies

Methodologies are curated prompt packs for common workflows:

```elixir
# Load methodology entries
entries = CommBus.Methodologies.entries_for("bug_triage")

# Or load specific entry
entries = CommBus.Methodologies.entries_for("bug_triage#severity-check")

# Combine with custom entries
all_entries = entries ++ [
  %Entry{id: "project-context", mode: :constant, content: "Project: MyApp..."}
]

# Assemble as usual
Assembler.assemble_prompt(conversation, all_entries)
```

### With Storage Adapter

```elixir
# Configure in config/config.exs
config :comm_bus,
  storage: CommBus.Storage.EctoAdapter,
  repo: MyApp.Repo

# Use in application
{:ok, conversation} = CommBus.Storage.get_conversation(conv_id)
{:ok, entries} = CommBus.Storage.list_entries(filters: [enabled: true])

result = Assembler.assemble_prompt(conversation, entries)
```

### With llm_core Integration

```elixir
alias CommBus.Protocol.LlmCoreAdapter

# 1. Assemble context
packet = Assembler.assemble_prompt(conversation, entries)

# 2. Convert to llm_core format
{:ok, llm_messages} = LlmCoreAdapter.to_provider_messages(packet)

# 3. Send to LLM via llm_core
{:ok, response} = LlmCore.complete(
  llm_messages,
  model: "gpt-4",
  provider: :openai
)
```

## Mix Tasks

CommBus provides several CLI utilities for development and testing.

### List Entries

View entries from any storage adapter:

```bash
# List all entries from InMemory storage
mix comm_bus.entries --store InMemory

# Filter by mode
mix comm_bus.entries --store InMemory --mode triggered

# Filter by enabled state
mix comm_bus.entries --store InMemory --enabled true
```

### Budget Simulation

Simulate token budget allocation:

```bash
mix comm_bus.budget \
  --conversation test/fixtures/conversations/basic.yml \
  --entries test/fixtures/entries/sample.yml \
  --total 1000
```

### Simulate Assembly

Full end-to-end assembly simulation:

```bash
mix comm_bus.simulate \
  --conversation test/fixtures/conversations/basic.yml \
  --entries test/fixtures/entries/sample.yml \
  --budget 2000
```

### Compare Template Engines

Compare BbMustache vs ExMustache rendering:

```bash
mix comm_bus.compare_engines
```

### Sync Test Fixtures

Synchronize golden template fixtures:

```bash
mix comm_bus.sync_fixtures
```

## Methodologies

CommBus includes a methodology system for reusable prompt packs.

### Built-in Methodologies

- **`bug_triage`** - Structured bug analysis and prioritization framework
- **`root_cause`** - Root cause analysis methodology

### Using Methodologies

```elixir
# Get all entries from a methodology
entries = CommBus.Methodologies.entries_for("bug_triage")

# Get specific entry by fragment identifier
entries = CommBus.Methodologies.entries_for("bug_triage#step-1")

# Load multiple methodologies
entries = CommBus.Methodologies.entries_for([
  "bug_triage",
  "root_cause#analysis"
])

# List available methodologies
methodologies = CommBus.Methodologies.list()
```

### Creating Custom Methodologies

Place YAML files in `config/comm_bus/methodologies/`:

```yaml
name: "API Development"
description: "Context entries for API development workflows"
slug: "api-dev"
tags: ["api", "rest", "development"]
entries:
  - id: "rest-principles"
    content: |
      REST API Design Principles:
      - Use HTTP methods correctly (GET, POST, PUT, DELETE)
      - Resource-based URLs
      - Stateless communication
    keywords: ["api", "rest", "endpoint"]
    section: pre_history
    mode: triggered
    priority: 80
    weight: 1.0

  - id: "error-handling"
    content: "Always return appropriate HTTP status codes..."
    keywords: ["error", "status", "response"]
    section: pre_history
    mode: triggered
    priority: 70
```

## Configuration

### Basic Configuration

```elixir
# config/config.exs
config :comm_bus,
  # Template engine (BbMustache is default)
  template_engine: CommBus.Template.Engine.BbMustache,

  # Tokenizer implementation
  tokenizer: CommBus.Tokenizer.Simple,

  # Prompt directory
  prompt_root: Path.expand("config/comm_bus/prompts", File.cwd!()),

  # Methodology directory
  methodology_root: Path.expand("config/comm_bus/methodologies", File.cwd!()),

  # Storage adapter
  storage: CommBus.Storage.InMemory
```

### Storage Configuration

#### In-Memory (Development/Testing)

```elixir
config :comm_bus,
  storage: CommBus.Storage.InMemory
```

#### Ecto Adapter (Production)

```elixir
config :comm_bus,
  storage: CommBus.Storage.EctoAdapter,
  repo: MyApp.Repo
```

You can implement custom storage adapters by adopting the `CommBus.Storage` behaviour.

## Architecture

```
┌─────────────────┐
│  Application    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────┐
│   CommBus       │────▶│  Storage     │
│   Assembler     │     │  Adapter     │
└────────┬────────┘     └──────────────┘
         │
         ▼
┌─────────────────┐
│   Matcher       │ ─── Keyword matching
└─────────────────┘

┌─────────────────┐
│   Budget        │ ─── Token fitting
└─────────────────┘

┌─────────────────┐
│   Protocol      │ ─── llm_core adapter
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   LLM Provider  │
└─────────────────┘
```

### Key Components

- **Assembler** - Orchestrates prompt assembly with keyword matching and budget fitting
- **Matcher** - Detects keyword triggers in conversation messages
- **Budget** - Fits entries within token constraints using priority-based selection
- **Budget.Planner** - Allocates tokens across sections (system, pre_history, history, post_history)
- **Tokenizer** - Counts tokens (pluggable implementation)
- **Template.Engine** - Renders Mustache templates with variable substitution
- **Prompts** - Manages prompt catalog with caching and file watching
- **Protocol.Pipeline** - ALF-based pipeline for assembly workflow
- **Storage** - Persistence layer with multiple adapter implementations

## Data Structures

### Entry

Injectable context with metadata:

```elixir
%CommBus.Entry{
  id: "unique-id",
  content: "Context information...",
  keywords: ["keyword1", "key*", "\"exact phrase\""],
  section: :pre_history,        # :system | :pre_history | :history | :post_history
  mode: :triggered,              # :constant | :triggered
  priority: 80,                  # Higher = more important
  weight: 1.0,                   # Multiplier for token budget
  token_count: 50,
  metadata: %{}
}
```

### Message

OpenAI-compatible message format:

```elixir
%CommBus.Message{
  role: :user,                   # :system | :user | :assistant | :tool
  content: "Message text...",
  token_count: 10,
  metadata: %{}
}
```

### Conversation

Session state with message history:

```elixir
%CommBus.Conversation{
  id: "conv-123",
  messages: [%Message{}, ...],
  depth: 3,                      # Number of exchanges
  metadata: %{}
}
```

### Packet

Assembly output ready for LLM:

```elixir
%CommBus.Protocol.Packet{
  messages: [%Message{}, ...],   # Sectioned and assembled
  sections: %{                   # Messages grouped by section
    system: [...],
    pre_history: [...],
    history: [...],
    post_history: [...]
  },
  included_entries: [...],       # Entries that fit in budget
  excluded_entries: [...],       # Entries that didn't fit
  token_usage: %{                # Token accounting
    total: 950,
    by_section: %{...}
  }
}
```

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/comm_bus/assembler_test.exs

# Run Mix task tests
mix test test/mix/tasks/

# Compare template engines
mix comm_bus.compare_engines

# Sync golden fixtures
mix comm_bus.sync_fixtures
```

## Documentation

Generate and view documentation locally:

```bash
mix docs
open doc/index.html
```

## Related Projects

- **[llm_core](https://github.com/fosferon/llm_core)** - LLM provider abstraction (sits below CommBus)

## License

MIT — see [LICENSE](LICENSE).
