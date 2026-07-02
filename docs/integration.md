# Integration Guide

Detailed integration patterns for CommBus: provider-agnostic LLM interaction via [llm_core](https://hex.pm/packages/llm_core), plus recipes for building custom storage adapters on top of your own database.

## llm_core Integration

CommBus is designed to work seamlessly with [llm_core](https://hex.pm/packages/llm_core) for provider-agnostic LLM interactions.

### Architecture

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌─────────────┐
│   Your App  │────▶│   CommBus    │────▶│   llm_core   │────▶│  LLM APIs   │
│             │     │  (Context)   │     │  (Provider)  │     │ (GPT/Claude)│
└─────────────┘     └──────────────┘     └──────────────┘     └─────────────┘
```

**CommBus**: Assembles context with keyword matching and budget management
**llm_core**: Abstracts provider APIs (OpenAI, Anthropic, Google, etc.)

### Setup

Add both dependencies:

```elixir
def deps do
  [
    {:comm_bus, "~> 0.2"},
    {:llm_core, "~> 0.4"}
  ]
end
```

### Basic Integration

```elixir
alias CommBus.{Assembler, Conversation, Entry, Message}
alias CommBus.Protocol.LlmCoreAdapter

# 1. Build conversation
conversation = %Conversation{
  messages: [
    %Message{role: :user, content: "How do I implement authentication?"}
  ]
}

# 2. Define entries
entries = [
  %Entry{
    id: "system",
    mode: :constant,
    section: :system,
    content: "You are a senior software engineer.",
    priority: 100
  },
  %Entry{
    id: "auth-guide",
    mode: :triggered,
    keywords: ["auth*", "login", "session"],
    section: :pre_history,
    content: "Authentication best practices: Use bcrypt for passwords, JWT for sessions...",
    priority: 80
  }
]

# 3. Assemble prompt with budget
packet = Assembler.assemble_prompt(
  conversation,
  entries,
  budget: %{total: 4000}
)

# 4. Convert to llm_core format
{:ok, llm_messages} = LlmCoreAdapter.to_provider_messages(packet)

# 5. Send to LLM via llm_core
{:ok, response} = LlmCore.complete(
  llm_messages,
  model: "gpt-4",
  provider: :openai,
  temperature: 0.7
)

# 6. Extract response
assistant_message = response.content
```

### Using the Protocol Pipeline

CommBus includes an ALF-based pipeline for streamlined assembly:

```elixir
alias CommBus.Protocol.Pipeline

# Single pipeline call handles everything
{:ok, result} = Pipeline.run(%{
  conversation: conversation,
  entries: entries,
  budget: %{total: 4000},
  adapter: :llm_core
})

# Result contains:
# - packet: CommBus.Protocol.Packet (assembled context)
# - provider_messages: llm_core format
# - metadata: assembly statistics
```

### Advanced: Streaming with llm_core

```elixir
defmodule MyApp.LLM.StreamHandler do
  alias CommBus.{Assembler, Protocol.LlmCoreAdapter}

  def stream_completion(conversation, entries, callback_pid) do
    # 1. Assemble context
    packet = Assembler.assemble_prompt(conversation, entries)

    # 2. Convert to llm_core format
    {:ok, llm_messages} = LlmCoreAdapter.to_provider_messages(packet)

    # 3. Stream with llm_core
    LlmCore.stream(
      llm_messages,
      model: "gpt-4",
      provider: :openai,
      stream_to: callback_pid
    )
  end
end

# Usage in GenServer or LiveView
def handle_info({:llm_chunk, chunk}, state) do
  # Process streaming chunk
  {:noreply, append_chunk(state, chunk)}
end
```

### Provider-Specific Configurations

**OpenAI (GPT-4)**:

```elixir
budget = %{
  total: 6000,  # 8K context - 2K for response
  sections: %{
    system: 500,
    pre_history: 2000,
    history: 2500,
    post_history: 1000
  }
}

{:ok, response} = LlmCore.complete(
  llm_messages,
  model: "gpt-4",
  provider: :openai,
  temperature: 0.7,
  max_tokens: 2000
)
```

**Anthropic (Claude 3 Opus)**:

```elixir
budget = %{
  total: 150_000,  # 200K context - 50K for response
  sections: %{
    system: 1000,
    pre_history: 50_000,
    history: 80_000,
    post_history: 19_000
  }
}

{:ok, response} = LlmCore.complete(
  llm_messages,
  model: "claude-3-opus-20240229",
  provider: :anthropic,
  temperature: 0.7,
  max_tokens: 4096
)
```

---

## Custom Storage Adapters

CommBus persists entries and conversations through behaviours, not a single
baked-in schema. Your application adopts `CommBus.Storage.EntryStore` and
`CommBus.Storage.ConversationStore` against whatever store you already run —
SQLite, PostgreSQL, Redis, or anything else.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐
│   Your App   │────▶│   CommBus    │────▶│  Your Storage Adapter │
│              │     │  (Context)   │     │  (EntryStore/Conv.)   │
└──────────────┘     └──────────────┘     └──────────────────────┘
```

### Option A: Ecto-backed adapter (PostgreSQL or SQLite)

`CommBus.Storage.EctoAdapter` is a generic helper that persists CommBus
entries and conversations through any Ecto repo. You point it at your own
repo and schema modules.

#### Schema

Create the tables in your application's own migration:

```elixir
# priv/repo/migrations/comm_bus_tables.exs
defmodule MyApp.Repo.Migrations.AddCommBusTables do
  use Ecto.Migration

  def change do
    create table(:comm_bus_entries, primary_key: false) do
      add :id, :string, primary_key: true
      add :content, :text, null: false
      add :keywords, {:array, :string}, default: []
      add :section, :string, null: false
      add :mode, :string, null: false
      add :priority, :integer, default: 50
      add :weight, :float, default: 1.0
      add :token_count, :integer
      add :enabled, :boolean, default: true
      add :tags, {:array, :string}, default: []
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:comm_bus_conversations, primary_key: false) do
      add :id, :string, primary_key: true
      add :depth, :integer, default: 0
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:comm_bus_messages) do
      add :conversation_id, references(:comm_bus_conversations, type: :string, on_delete: :delete_all)
      add :role, :string, null: false
      add :content, :text, null: false
      add :token_count, :integer
      add :metadata, :map, default: %{}
      add :position, :integer, null: false

      timestamps()
    end

    create index(:comm_bus_entries, [:enabled])
    create index(:comm_bus_entries, [:section])
    create index(:comm_bus_entries, [:mode])
    create index(:comm_bus_entries, [:tags], using: :gin)
    create index(:comm_bus_messages, [:conversation_id])
    create index(:comm_bus_messages, [:conversation_id, :position])
  end
end
```

Run the migration:

```bash
mix ecto.migrate
```

#### Configuration

```elixir
# config/config.exs
config :comm_bus,
  storage: CommBus.Storage.EctoAdapter,
  repo: MyApp.Repo
```

### Option B: Fully custom adapter (any data store)

Adopt the behaviours directly for non-Ecto stores or bespoke schemas. This is
how any application plugs its existing persistence layer into CommBus:

```elixir
defmodule MyApp.Storage do
  @behaviour CommBus.Storage.EntryStore
  @behaviour CommBus.Storage.ConversationStore

  @impl true
  def store_entry(%CommBus.Entry{} = entry) do
    # write to your store (Redis, SQLite via direct driver, an external API, ...)
    {:ok, entry}
  end

  @impl true
  def list_entries(opts) do
    # honour filters in opts (e.g. enabled: true, tags: [...])
    {:ok, []}
  end

  @impl true
  def get_entry(id), do: {:error, :not_found}

  @impl true
  def delete_entry(_id), do: :ok

  @impl true
  def store_conversation(conversation), do: {:ok, conversation}

  @impl true
  def load_conversation(_id), do: {:error, :not_found}

  @impl true
  def update_conversation(_id, _attrs), do: {:ok, nil}
end
```

```elixir
# config/config.exs
config :comm_bus,
  storage: MyApp.Storage
```

### Using stored entries in an assembly

Regardless of which adapter you choose, the read path is the same:

```elixir
alias CommBus.{Assembler, Conversation, Message, Methodologies}

defmodule MyApp.Workflows.CommitMessage do
  def generate(diff_content) do
    # 1. Load methodology entries (curated prompt packs)
    method_entries = Methodologies.entries_for("bug_triage")

    # 2. Load workflow-specific entries from your own store
    {:ok, workflow_entries} = CommBus.Storage.EntryStore.list_entries(
      filters: [enabled: true]
    )

    # 3. Build conversation with the user content
    conversation = %Conversation{
      messages: [
        %Message{role: :user, content: "Generate a commit message for:\n\n#{diff_content}"}
      ]
    }

    # 4. Assemble context
    packet = Assembler.assemble_prompt(conversation, method_entries ++ workflow_entries)

    packet
  end
end
```

---

## Per-Entry Classification with Axis

CommBus ships a generic per-entry classification facility via `CommBus.Axis`.
An *axis* is a named dimension (with a value domain and default) that your
application declares; per-entry values are carried in `Entry.metadata`. This is
useful whenever a downstream consumer needs to tell declared categories of
content apart — for example, separating content the model should keep to itself
from content the model is instructed to surface.

comm_bus owns only the mechanism; your application declares the vocabulary:

```elixir
CommBus.Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)

entry = %CommBus.Entry{metadata: %{"visibility" => "disclosed"}}
{:ok, :disclosed} = CommBus.Axis.get(entry, :visibility)
{:ok, :internal}  = CommBus.Axis.get(%CommBus.Entry{}, :visibility)  # default fallback
```

See the `CommBus.Axis` module documentation for the full API.

---

## Cross-Cutting Patterns

### Unified Telemetry

Monitor CommBus operations across your application:

```elixir
defmodule MyApp.CommBusTelemetry do
  require Logger

  def attach do
    :telemetry.attach_many(
      "comm-bus-telemetry",
      [
        [:comm_bus, :assembly, :start],
        [:comm_bus, :assembly, :stop],
        [:comm_bus, :assembly, :exception],
        [:comm_bus, :storage, :query]
      ],
      &handle_event/4,
      nil
    )
  end

  def handle_event([:comm_bus, :assembly, :stop], measurements, metadata, _config) do
    Logger.info("""
    CommBus assembly completed:
    - Duration: #{measurements.duration}ms
    - Tokens: #{metadata.token_usage}
    - Entries included: #{length(metadata.included_entries)}
    - Entries excluded: #{length(metadata.excluded_entries)}
    """)

    # Send to metrics system
    :telemetry.execute(
      [:my_app, :comm_bus, :tokens],
      %{count: metadata.token_usage},
      %{section: :total}
    )
  end

  def handle_event([:comm_bus, :assembly, :exception], _measurements, metadata, _config) do
    Logger.error("CommBus assembly failed: #{inspect(metadata.error)}")
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok
end
```

### Full Stack Example

Complete example integrating CommBus, llm_core, and a custom storage adapter:

```elixir
defmodule MyApp.LLM.ContextAssembler do
  @moduledoc """
  Unified context assembly for LLM interactions.
  Integrates CommBus with llm_core for provider-agnostic completions.
  """

  alias CommBus.{Assembler, Conversation, Message, Methodologies, Storage}
  alias CommBus.Protocol.LlmCoreAdapter

  def complete_with_context(conversation, opts \\ []) do
    # 1. Load methodology entries
    methodology = Keyword.get(opts, :methodology, "general")
    methodology_entries = Methodologies.entries_for(methodology)

    # 2. Load stored entries (filtered by tags if provided)
    {:ok, stored_entries} = Storage.EntryStore.list_entries(
      filters: build_filters(opts)
    )

    # 3. Combine entries
    all_entries = methodology_entries ++ stored_entries

    # 4. Assemble with budget
    budget = Keyword.get(opts, :budget, default_budget())
    packet = Assembler.assemble_prompt(conversation, all_entries, budget: budget)

    # 5. Convert to llm_core format
    {:ok, messages} = LlmCoreAdapter.to_provider_messages(packet)

    # 6. Complete with LLM
    llm_opts = Keyword.take(opts, [:model, :provider, :temperature, :max_tokens])
    {:ok, response} = LlmCore.complete(messages, llm_opts)

    # 7. Return response with metadata
    {:ok, %{
      content: response.content,
      packet: packet,
      token_usage: packet.token_usage,
      model: response.model
    }}
  end

  defp build_filters(opts) do
    base = [enabled: true]

    case Keyword.get(opts, :tags) do
      nil -> base
      tags -> Keyword.put(base, :tags, tags)
    end
  end

  defp default_budget do
    %{
      total: 4000,
      sections: %{
        system: 400,
        pre_history: 1200,
        history: 1600,
        post_history: 800
      }
    }
  end
end
```

## Next Steps

- Review [Adopting CommBus](adopting_commbus.md) for general integration guidance
- Explore the [API documentation](https://hexdocs.pm/comm_bus) for detailed module references
- Check the [GitHub repository](https://github.com/fosferon/comm_bus) for source code and examples

## Support

- [GitHub Issues](https://github.com/fosferon/comm_bus/issues)
- [HexDocs](https://hexdocs.pm/comm_bus)
