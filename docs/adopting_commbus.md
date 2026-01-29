# Adopting CommBus

A step-by-step guide for integrating CommBus into your Elixir application to add intelligent context management for LLM interactions.

## Prerequisites

- Elixir ~> 1.17
- Mix project (Phoenix, Nerves, or standalone Elixir app)
- For Ecto adapter: Ecto ~> 3.11
- Basic familiarity with LLM prompt engineering

## Installation Steps

### 1. Add Dependency

Add CommBus to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:comm_bus, "~> 0.1.0"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
mix compile
```

### 2. Choose Storage Strategy

CommBus supports multiple storage adapters depending on your needs.

#### Option A: In-Memory (Development/Testing)

Best for: Development, testing, proof-of-concept

```elixir
# config/dev.exs
config :comm_bus,
  storage: CommBus.Storage.InMemory
```

**Pros**: Zero setup, fast, no database required
**Cons**: Data lost on restart, not suitable for production

#### Option B: Ecto Adapter (Production)

Best for: Production applications with existing Ecto setup

```elixir
# config/prod.exs
config :comm_bus,
  storage: CommBus.Storage.EctoAdapter,
  repo: MyApp.Repo
```

**Migration Setup**:

```bash
mix ecto.gen.migration add_comm_bus_tables
```

Edit the generated migration file:

```elixir
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

Run migration:

```bash
mix ecto.migrate
```

**Pros**: Production-ready, persistent, scales with your database
**Cons**: Requires Ecto setup and migrations

#### Option C: DevMan Adapter (SQLite)

Best for: Integration with DevMan workflow tool

```elixir
# config/config.exs
config :comm_bus,
  storage: CommBus.Storage.Devman,
  db_path: Path.expand("~/.devman/devman.db")
```

Requires DevMan SQLite schema already set up.

#### Option D: HuMan Adapter (PostgreSQL)

Best for: Integration with HuMan reasoning infrastructure

```elixir
# config/config.exs
config :comm_bus,
  storage: CommBus.Storage.Human,
  repo: HuMan.Repo

# HuMan repo configuration
config :human, HuMan.Repo,
  database: "human_dev",
  hostname: "localhost",
  pool_size: 10
```

Requires HuMan PostgreSQL schema already set up.

### 3. Configure Template Engine

CommBus supports two Mustache engines:

```elixir
# config/config.exs
config :comm_bus,
  # Option 1: BbMustache (default, faster, Erlang-based)
  template_engine: CommBus.Template.Engine.BbMustache,

  # Option 2: ExMustache (pure Elixir)
  # template_engine: CommBus.Template.Engine.ExMustache,

  # Prompt directory
  prompt_root: Path.expand("config/comm_bus/prompts", File.cwd!()),

  # Methodology directory
  methodology_root: Path.expand("config/comm_bus/methodologies", File.cwd!())
```

### 4. Set Up Directory Structure

Create directories for prompts and methodologies:

```bash
mkdir -p config/comm_bus/prompts
mkdir -p config/comm_bus/methodologies
```

**Example prompt file** (`config/comm_bus/prompts/greeting.md`):

```markdown
---
name: greeting
description: Friendly greeting template
variables:
  - name
  - role
---
Hello {{name}}! I'm here to help you with {{role}}.
```

**Example methodology file** (`config/comm_bus/methodologies/custom.yml`):

```yaml
name: "Custom Workflow"
description: "Context entries for custom workflow"
slug: "custom"
tags: ["workflow", "custom"]
entries:
  - id: "step-1"
    content: "Step 1 instructions..."
    keywords: ["start", "begin"]
    section: pre_history
    mode: triggered
    priority: 80
```

### 5. Configure Tokenizer

CommBus uses a pluggable tokenizer. The default is `Simple` (heuristic-based):

```elixir
# config/config.exs
config :comm_bus,
  tokenizer: CommBus.Tokenizer.Simple
```

**Custom Tokenizer** (optional):

If you want accurate token counting for specific models, implement the `CommBus.Tokenizer` behaviour:

```elixir
defmodule MyApp.GPT4Tokenizer do
  @behaviour CommBus.Tokenizer

  def count_tokens(text) do
    # Use tiktoken_elixir or similar
    MyApp.Tiktoken.count(text, model: "gpt-4")
  end
end

# Configure
config :comm_bus, tokenizer: MyApp.GPT4Tokenizer
```

## Usage Patterns

### Pattern 1: Basic Assembly in Controllers/Services

**Phoenix Controller Example**:

```elixir
defmodule MyAppWeb.ChatController do
  use MyAppWeb, :controller
  alias CommBus.{Assembler, Conversation, Entry, Message}

  def create(conn, %{"message" => user_message, "session_id" => session_id}) do
    # 1. Get or create conversation
    conversation = get_or_create_conversation(session_id, user_message)

    # 2. Load context entries
    {:ok, entries} = CommBus.Storage.list_entries(filters: [enabled: true])

    # 3. Assemble prompt
    packet = Assembler.assemble_prompt(
      conversation,
      entries,
      budget: %{total: 4000}
    )

    # 4. Send to LLM (via llm_core or direct API)
    {:ok, response} = call_llm(packet.messages)

    # 5. Save assistant response
    updated_conversation = append_message(conversation, :assistant, response)
    CommBus.Storage.upsert_conversation(updated_conversation)

    json(conn, %{response: response})
  end

  defp get_or_create_conversation(session_id, user_message) do
    case CommBus.Storage.get_conversation(session_id) do
      {:ok, conv} ->
        %{conv | messages: conv.messages ++ [
          %Message{role: :user, content: user_message}
        ]}

      {:error, :not_found} ->
        %Conversation{
          id: session_id,
          messages: [%Message{role: :user, content: user_message}]
        }
    end
  end
end
```

### Pattern 2: Background Jobs with Oban

**Process long conversations asynchronously**:

```elixir
defmodule MyApp.Workers.ConversationProcessor do
  use Oban.Worker, queue: :llm, max_attempts: 3

  alias CommBus.{Assembler, Methodologies}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => conv_id, "methodology" => methodology}}) do
    # 1. Load conversation from storage
    {:ok, conversation} = CommBus.Storage.get_conversation(conv_id)

    # 2. Load methodology entries
    method_entries = Methodologies.entries_for(methodology)

    # 3. Load stored entries
    {:ok, stored_entries} = CommBus.Storage.list_entries(filters: [enabled: true])

    # 4. Combine entries
    all_entries = method_entries ++ stored_entries

    # 5. Assemble with generous budget
    packet = Assembler.assemble_prompt(
      conversation,
      all_entries,
      budget: %{total: 8000}
    )

    # 6. Process with LLM
    {:ok, response} = MyApp.LLM.complete(packet.messages)

    # 7. Save result
    updated = %{conversation | messages: conversation.messages ++ [
      %Message{role: :assistant, content: response}
    ]}
    CommBus.Storage.upsert_conversation(updated)

    :ok
  end
end

# Enqueue job
MyApp.Workers.ConversationProcessor.new(%{
  "conversation_id" => "conv-123",
  "methodology" => "bug_triage"
})
|> Oban.insert()
```

### Pattern 3: Real-time Streaming with Phoenix LiveView

**Stream LLM responses with context assembly**:

```elixir
defmodule MyAppWeb.ChatLive do
  use MyAppWeb, :live_view
  alias CommBus.{Assembler, Conversation, Message}

  def mount(%{"session_id" => session_id}, _session, socket) do
    {:ok, conversation} = CommBus.Storage.get_conversation(session_id)

    socket =
      socket
      |> assign(:conversation, conversation)
      |> assign(:streaming, false)

    {:ok, socket}
  end

  def handle_event("send_message", %{"message" => content}, socket) do
    # Add user message
    conversation = socket.assigns.conversation
    updated = %{conversation |
      messages: conversation.messages ++ [
        %Message{role: :user, content: content}
      ]
    }

    # Assemble context
    {:ok, entries} = CommBus.Storage.list_entries(filters: [enabled: true])
    packet = Assembler.assemble_prompt(updated, entries)

    # Start streaming
    {:ok, stream_pid} = MyApp.LLM.stream(packet.messages, self())

    socket =
      socket
      |> assign(:conversation, updated)
      |> assign(:streaming, true)
      |> assign(:stream_pid, stream_pid)

    {:noreply, socket}
  end

  def handle_info({:stream_chunk, chunk}, socket) do
    # Append chunk to UI
    {:noreply, push_event(socket, "chunk", %{data: chunk})}
  end

  def handle_info(:stream_complete, socket) do
    {:noreply, assign(socket, :streaming, false)}
  end
end
```

### Pattern 4: Dynamic Entry Management

**Update context entries at runtime**:

```elixir
defmodule MyApp.ContextManager do
  alias CommBus.{Entry, Storage}

  def add_project_context(project_id) do
    project = MyApp.Projects.get!(project_id)

    entry = %Entry{
      id: "project-#{project_id}",
      content: """
      Project: #{project.name}
      Tech Stack: #{Enum.join(project.technologies, ", ")}
      Status: #{project.status}
      """,
      keywords: [project.name, "project", "codebase"],
      section: :pre_history,
      mode: :triggered,
      priority: 70,
      enabled: true,
      tags: ["project", "context"]
    }

    Storage.insert_entry(entry)
  end

  def disable_outdated_entries do
    {:ok, entries} = Storage.list_entries(filters: [enabled: true])

    entries
    |> Enum.filter(&outdated?/1)
    |> Enum.each(fn entry ->
      Storage.update_entry(entry.id, enabled: false)
    end)
  end

  defp outdated?(entry) do
    # Custom logic to determine if entry is outdated
    case entry.metadata do
      %{"expires_at" => expires_at} ->
        DateTime.compare(DateTime.utc_now(), expires_at) == :gt
      _ ->
        false
    end
  end
end
```

## Testing

### Test with In-Memory Storage

```elixir
# test/test_helper.exs
Application.put_env(:comm_bus, :storage, CommBus.Storage.InMemory)

# test/my_app/chat_test.exs
defmodule MyApp.ChatTest do
  use MyApp.DataCase
  alias CommBus.{Assembler, Conversation, Entry, Message}

  setup do
    # Clear in-memory storage between tests
    :ets.delete_all_objects(:comm_bus_entries)
    :ets.delete_all_objects(:comm_bus_conversations)
    :ok
  end

  test "assembles context for bug report" do
    conversation = %Conversation{
      messages: [
        %Message{role: :user, content: "Bug in auth system"}
      ]
    }

    entries = [
      %Entry{
        id: "auth-docs",
        keywords: ["auth*", "login"],
        section: :pre_history,
        content: "Auth system documentation...",
        mode: :triggered
      }
    ]

    result = Assembler.assemble_prompt(conversation, entries)

    assert length(result.included_entries) == 1
    assert hd(result.included_entries).id == "auth-docs"
  end
end
```

## Production Considerations

### Token Budget Tuning

Adjust budgets based on your LLM provider and model:

```elixir
# For GPT-4 (8K context)
budget = %{
  total: 6000,  # Leave room for response
  sections: %{
    system: 500,
    pre_history: 2000,
    history: 2500,
    post_history: 1000
  }
}

# For Claude 3 Opus (200K context)
budget = %{
  total: 150_000,
  sections: %{
    system: 1000,
    pre_history: 50_000,
    history: 80_000,
    post_history: 19_000
  }
}
```

### Prompt Override Storage

For runtime prompt overrides without redeploying:

```elixir
defmodule MyApp.PromptOverrideStore do
  @behaviour CommBus.Prompts.OverrideStore

  def get_override(prompt_name) do
    case MyApp.Repo.get_by(PromptOverride, name: prompt_name) do
      %{content: content} -> {:ok, content}
      nil -> :not_found
    end
  end

  def set_override(prompt_name, content) do
    %PromptOverride{name: prompt_name, content: content}
    |> MyApp.Repo.insert!(
      on_conflict: {:replace, [:content, :updated_at]},
      conflict_target: :name
    )
    :ok
  end
end

# Configure
config :comm_bus,
  prompt_override_store: MyApp.PromptOverrideStore
```

### Telemetry Monitoring

Monitor assembly performance:

```elixir
:telemetry.attach_many(
  "comm-bus-handler",
  [
    [:comm_bus, :assembly, :start],
    [:comm_bus, :assembly, :stop],
    [:comm_bus, :assembly, :exception]
  ],
  &MyApp.Telemetry.handle_event/4,
  nil
)

defmodule MyApp.Telemetry do
  require Logger

  def handle_event([:comm_bus, :assembly, :start], _measurements, metadata, _config) do
    Logger.debug("Assembly started for conversation #{metadata.conversation_id}")
  end

  def handle_event([:comm_bus, :assembly, :stop], measurements, metadata, _config) do
    Logger.info("Assembly completed in #{measurements.duration}ms, tokens: #{metadata.token_usage}")
  end

  def handle_event([:comm_bus, :assembly, :exception], measurements, metadata, _config) do
    Logger.error("Assembly failed: #{inspect(metadata.error)}")
  end
end
```

### Performance Optimization

**1. Entry Caching**:

```elixir
defmodule MyApp.CachedEntryLoader do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_entries do
    GenServer.call(__MODULE__, :get_entries)
  end

  def init(_) do
    schedule_refresh()
    {:ok, load_entries()}
  end

  def handle_call(:get_entries, _from, entries) do
    {:reply, entries, entries}
  end

  def handle_info(:refresh, _entries) do
    schedule_refresh()
    {:noreply, load_entries()}
  end

  defp load_entries do
    {:ok, entries} = CommBus.Storage.list_entries(filters: [enabled: true])
    entries
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, :timer.minutes(5))
  end
end
```

**2. Prompt Preloading**:

CommBus automatically caches prompts in `:persistent_term`, but you can preload them on application start:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    # Preload all prompts
    CommBus.Prompts.Runtime.preload_all()

    children = [
      # ... other children
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

## Migration from Other Solutions

### From Direct OpenAI API Calls

**Before**:

```elixir
messages = [
  %{role: "system", content: "You are a helpful assistant."},
  %{role: "user", content: user_input}
]

OpenAI.chat_completion(messages, model: "gpt-4")
```

**After** (with CommBus):

```elixir
conversation = %Conversation{
  messages: [%Message{role: :user, content: user_input}]
}

entries = [
  %Entry{id: "system", mode: :constant, section: :system, content: "You are a helpful assistant."}
]

packet = Assembler.assemble_prompt(conversation, entries)
OpenAI.chat_completion(packet.messages, model: "gpt-4")
```

**Benefits**: Dynamic context injection, token budget management, keyword-triggered entries

### From LangChain

CommBus complements LangChain by handling context assembly before chains execute:

```elixir
# Assemble context with CommBus
packet = CommBus.Assembler.assemble_prompt(conversation, entries)

# Use in LangChain
chain = %{llm: ChatOpenAI.new!(%{model: "gpt-4"})}
LLMChain.run(chain, messages: packet.messages)
```

## Next Steps

- Read the [Integration Guide](integration.md) for DevMan, HuMan, and llm_core integration patterns
- Explore the [API documentation](https://hexdocs.pm/comm_bus) for detailed module references
- Review [CHANGELOG.md](../CHANGELOG.md) for version history and updates

## Support

- [GitHub Issues](https://github.com/fosferon/comm_bus/issues)
- [Hex Package](https://hex.pm/packages/comm_bus)
- [HexDocs](https://hexdocs.pm/comm_bus)
