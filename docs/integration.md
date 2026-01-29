# Integration Guide

Detailed integration patterns for CommBus with companion libraries: llm_core (LLM provider abstraction), DevMan (workflow orchestration), and HuMan (reasoning infrastructure).

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
    {:comm_bus, "~> 0.1.0"},
    {:llm_core, "~> 0.x.x"}  # Check latest version
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

## DevMan Integration

DevMan is a CLI workflow orchestration tool that uses CommBus for context management in automated development workflows.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  DevMan CLI  │────▶│   CommBus    │────▶│   SQLite DB  │
│  (Workflows) │     │  (Context)   │     │  (Storage)   │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Storage Configuration

DevMan uses the SQLite-backed storage adapter:

```elixir
# config/config.exs (in DevMan project)
config :comm_bus,
  storage: CommBus.Storage.Devman,
  db_path: Path.expand("~/.devman/devman.db")
```

### Schema

The DevMan adapter expects these tables in the SQLite database:

```sql
-- Entries table
CREATE TABLE comm_bus_entries (
  id TEXT PRIMARY KEY,
  content TEXT NOT NULL,
  keywords TEXT,  -- JSON array
  section TEXT NOT NULL,
  mode TEXT NOT NULL,
  priority INTEGER DEFAULT 50,
  weight REAL DEFAULT 1.0,
  token_count INTEGER,
  enabled INTEGER DEFAULT 1,
  tags TEXT,  -- JSON array
  metadata TEXT,  -- JSON object
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Conversations table
CREATE TABLE comm_bus_conversations (
  id TEXT PRIMARY KEY,
  depth INTEGER DEFAULT 0,
  metadata TEXT,  -- JSON object
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Messages table
CREATE TABLE comm_bus_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  token_count INTEGER,
  position INTEGER NOT NULL,
  metadata TEXT,  -- JSON object
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (conversation_id) REFERENCES comm_bus_conversations(id) ON DELETE CASCADE
);

CREATE INDEX idx_entries_enabled ON comm_bus_entries(enabled);
CREATE INDEX idx_entries_section ON comm_bus_entries(section);
CREATE INDEX idx_entries_mode ON comm_bus_entries(mode);
CREATE INDEX idx_messages_conversation ON comm_bus_messages(conversation_id);
CREATE INDEX idx_messages_position ON comm_bus_messages(conversation_id, position);
```

### Usage in DevMan Workflows

**Example: Commit Message Generation**:

```elixir
defmodule DevMan.Workflows.CommitMessage do
  alias CommBus.{Assembler, Conversation, Message, Methodologies}

  def generate(diff_content) do
    # 1. Load commit methodology
    method_entries = Methodologies.entries_for("devman#commit-helper")

    # 2. Load workflow-specific entries
    {:ok, workflow_entries} = CommBus.Storage.Devman.list_entries(
      filters: [tags: ["commit"], enabled: true]
    )

    # 3. Build conversation with diff
    conversation = %Conversation{
      messages: [
        %Message{
          role: :user,
          content: """
          Generate a commit message for this diff:

          #{diff_content}
          """
        }
      ]
    }

    # 4. Assemble context
    all_entries = method_entries ++ workflow_entries
    packet = Assembler.assemble_prompt(conversation, all_entries)

    # 5. Send to LLM
    {:ok, response} = DevMan.LLM.complete(packet.messages)

    response.content
  end
end
```

### Methodology Integration

DevMan leverages methodologies for workflow-specific contexts:

```yaml
# config/comm_bus/methodologies/devman.yml
name: "DevMan Workflows"
description: "Context entries for DevMan development workflows"
slug: "devman"
tags: ["devman", "workflow", "automation"]

entries:
  - id: "commit-helper"
    content: |
      Follow conventional commits format:
      - feat: A new feature
      - fix: A bug fix
      - docs: Documentation only changes
      - style: Changes that don't affect code meaning
      - refactor: Code change that neither fixes a bug nor adds a feature
      - perf: Performance improvement
      - test: Adding missing tests
      - chore: Changes to build process or auxiliary tools

      Format: <type>(<scope>): <subject>

      Keep subject line under 50 characters.
      Use imperative mood ("add" not "added").
    keywords: ["commit", "message", "git"]
    section: pre_history
    mode: triggered
    priority: 90

  - id: "code-review-guidelines"
    content: |
      Code review focus areas:
      1. Correctness: Does the code do what it's supposed to?
      2. Maintainability: Is it readable and well-structured?
      3. Performance: Any obvious inefficiencies?
      4. Security: Any vulnerabilities introduced?
      5. Tests: Are there adequate tests?
    keywords: ["review", "pr", "code quality"]
    section: pre_history
    mode: triggered
    priority: 85

  - id: "bug-analysis"
    content: |
      Bug analysis framework:
      1. Reproduce: Can you reproduce the bug?
      2. Isolate: What's the minimal reproduction case?
      3. Root cause: What's causing the issue?
      4. Impact: Who/what is affected?
      5. Fix: What's the appropriate fix?
      6. Prevention: How to prevent similar bugs?
    keywords: ["bug", "issue", "error", "fix"]
    section: pre_history
    mode: triggered
    priority: 85
```

### CLI Integration

DevMan's CLI can expose CommBus functionality:

```bash
# List entries
devman context list

# Add entry
devman context add \
  --id "project-rules" \
  --content "Project-specific coding standards..." \
  --keywords "standards,style,conventions" \
  --section pre_history

# Enable/disable entries
devman context disable project-rules

# Test assembly
devman context test "Fix auth bug" --methodology bug_triage
```

### Workflow Example: Automated PR Description

```elixir
defmodule DevMan.Workflows.PRDescription do
  alias CommBus.{Assembler, Conversation, Message}

  def generate(branch_name, commits) do
    # Build conversation from git history
    conversation = %Conversation{
      messages: [
        %Message{
          role: :user,
          content: """
          Generate a PR description for branch: #{branch_name}

          Commits:
          #{format_commits(commits)}
          """
        }
      ]
    }

    # Load entries (methodology + stored)
    entries = load_entries(["pr", "documentation"])

    # Assemble and send to LLM
    packet = Assembler.assemble_prompt(conversation, entries)
    {:ok, response} = DevMan.LLM.complete(packet.messages)

    response.content
  end

  defp load_entries(tags) do
    {:ok, stored} = CommBus.Storage.Devman.list_entries(
      filters: [tags: tags, enabled: true]
    )

    method = CommBus.Methodologies.entries_for("devman#pr-helper")

    stored ++ method
  end

  defp format_commits(commits) do
    commits
    |> Enum.map(fn %{hash: h, message: m} -> "#{h}: #{m}" end)
    |> Enum.join("\n")
  end
end
```

---

## HuMan Integration

HuMan is a reasoning infrastructure that uses CommBus for managing reasoning session contexts with PostgreSQL storage.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    HuMan     │────▶│   CommBus    │────▶│  PostgreSQL  │
│  (Reasoning) │     │  (Context)   │     │  (Storage)   │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Storage Configuration

HuMan uses the PostgreSQL-backed storage adapter:

```elixir
# config/config.exs (in HuMan project)
config :comm_bus,
  storage: CommBus.Storage.Human,
  repo: HuMan.Repo

config :human, HuMan.Repo,
  database: "human_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10
```

### Schema Integration

HuMan integrates CommBus tables with its reasoning infrastructure:

```elixir
# In HuMan migration
defmodule HuMan.Repo.Migrations.AddCommBusTables do
  use Ecto.Migration

  def change do
    # CommBus entries (linked to reasoning sessions)
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
      add :metadata, :jsonb, default: "{}"

      # HuMan-specific: link to reasoning session
      add :reasoning_session_id, references(:reasoning_sessions, on_delete: :nilify_all)

      timestamps()
    end

    # CommBus conversations (alias for reasoning sessions)
    create table(:comm_bus_conversations, primary_key: false) do
      add :id, :string, primary_key: true
      add :depth, :integer, default: 0
      add :metadata, :jsonb, default: "{}"

      # Link to HuMan reasoning session
      add :reasoning_session_id, references(:reasoning_sessions, on_delete: :cascade)

      timestamps()
    end

    # CommBus messages
    create table(:comm_bus_messages) do
      add :conversation_id, references(:comm_bus_conversations, type: :string, on_delete: :delete_all)
      add :role, :string, null: false
      add :content, :text, null: false
      add :token_count, :integer
      add :position, :integer, null: false
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    create index(:comm_bus_entries, [:enabled])
    create index(:comm_bus_entries, [:section])
    create index(:comm_bus_entries, [:tags], using: :gin)
    create index(:comm_bus_entries, [:reasoning_session_id])
    create index(:comm_bus_messages, [:conversation_id])
    create index(:comm_bus_messages, [:conversation_id, :position])
  end
end
```

### Reasoning Session Integration

```elixir
defmodule HuMan.ReasoningSession do
  alias CommBus.{Assembler, Conversation, Message}
  alias HuMan.Repo

  def assemble_context(session_id) do
    # 1. Get reasoning session
    session = Repo.get!(ReasoningSession, session_id)

    # 2. Load CommBus conversation
    {:ok, conversation} = CommBus.Storage.Human.get_conversation(
      "session-#{session_id}"
    )

    # 3. Load session-specific entries
    {:ok, entries} = CommBus.Storage.Human.list_entries(
      filters: [reasoning_session_id: session_id, enabled: true]
    )

    # 4. Load reasoning methodology
    method_entries = CommBus.Methodologies.entries_for("human#chain-of-thought")

    # 5. Assemble with session budget
    all_entries = entries ++ method_entries
    packet = Assembler.assemble_prompt(
      conversation,
      all_entries,
      budget: session.budget_config
    )

    packet
  end

  def add_reasoning_step(session_id, step_content) do
    {:ok, conversation} = CommBus.Storage.Human.get_conversation("session-#{session_id}")

    updated = %{conversation |
      messages: conversation.messages ++ [
        %Message{role: :assistant, content: step_content}
      ]
    }

    CommBus.Storage.Human.upsert_conversation(updated)
  end
end
```

### Methodology for Reasoning

```yaml
# config/comm_bus/methodologies/human.yml
name: "HuMan Reasoning"
description: "Context entries for reasoning infrastructure"
slug: "human"
tags: ["reasoning", "chain-of-thought", "analysis"]

entries:
  - id: "chain-of-thought"
    content: |
      Reasoning Framework (Chain of Thought):

      1. **Problem Understanding**
         - What is being asked?
         - What are the constraints?
         - What information is available?

      2. **Decomposition**
         - Break down into smaller sub-problems
         - Identify dependencies
         - Determine order of operations

      3. **Step-by-Step Reasoning**
         - Work through each sub-problem
         - Show your work
         - Validate intermediate results

      4. **Synthesis**
         - Combine sub-solutions
         - Check against original problem
         - Verify completeness

      5. **Reflection**
         - Review reasoning process
         - Identify potential errors
         - Consider alternative approaches
    keywords: ["reason", "think", "analyze", "solve"]
    section: pre_history
    mode: triggered
    priority: 95

  - id: "verification"
    content: |
      Verification Checklist:
      - Does the solution address all requirements?
      - Are there edge cases not considered?
      - Is the logic sound at each step?
      - Can the solution be simplified?
      - Are there any assumptions that need validation?
    keywords: ["verify", "check", "validate", "test"]
    section: post_history
    mode: triggered
    priority: 80

  - id: "metacognition"
    content: |
      Metacognitive Prompts:
      - What do I know? What don't I know?
      - What strategies am I using?
      - Is this strategy working?
      - Should I try a different approach?
      - What have I learned from this?
    keywords: ["meta", "reflect", "review", "improve"]
    section: post_history
    mode: triggered
    priority: 75
```

### Advanced: Dynamic Entry Management

```elixir
defmodule HuMan.ContextManager do
  alias CommBus.{Entry, Storage.Human}

  def add_session_context(session_id, context_type, content) do
    entry = %Entry{
      id: "session-#{session_id}-#{context_type}",
      content: content,
      keywords: extract_keywords(content),
      section: :pre_history,
      mode: :triggered,
      priority: 70,
      enabled: true,
      tags: ["session", context_type],
      metadata: %{
        reasoning_session_id: session_id,
        created_at: DateTime.utc_now()
      }
    }

    Human.insert_entry(entry)
  end

  def update_session_budget(session_id, new_budget) do
    {:ok, conversation} = Human.get_conversation("session-#{session_id}")

    updated_metadata = Map.put(conversation.metadata, :budget, new_budget)
    updated = %{conversation | metadata: updated_metadata}

    Human.upsert_conversation(updated)
  end

  defp extract_keywords(content) do
    content
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> -count end)
    |> Enum.take(10)
    |> Enum.map(fn {word, _count} -> word end)
  end
end
```

### Reasoning Trace Storage

```elixir
defmodule HuMan.ReasoningTrace do
  alias CommBus.{Conversation, Message}

  def start_trace(problem_description) do
    conversation = %Conversation{
      id: "trace-#{Ecto.UUID.generate()}",
      messages: [
        %Message{
          role: :user,
          content: problem_description
        }
      ],
      metadata: %{
        started_at: DateTime.utc_now(),
        trace_type: :reasoning
      }
    }

    {:ok, _} = CommBus.Storage.Human.upsert_conversation(conversation)
    {:ok, conversation.id}
  end

  def add_step(trace_id, role, content) do
    {:ok, conversation} = CommBus.Storage.Human.get_conversation(trace_id)

    updated = %{conversation |
      messages: conversation.messages ++ [
        %Message{
          role: role,
          content: content
        }
      ],
      depth: conversation.depth + 1
    }

    CommBus.Storage.Human.upsert_conversation(updated)
  end

  def get_trace(trace_id) do
    CommBus.Storage.Human.get_conversation(trace_id)
  end
end
```

---

## Cross-Integration Patterns

### Shared Methodologies

Both DevMan and HuMan can share methodology definitions:

```
config/comm_bus/methodologies/
├── shared/
│   ├── root_cause.yml      # Shared by both
│   └── bug_triage.yml      # Shared by both
├── devman/
│   ├── workflows.yml       # DevMan-specific
│   └── commit_helper.yml
└── human/
    ├── reasoning.yml       # HuMan-specific
    └── verification.yml
```

### Unified Telemetry

Monitor CommBus operations across all integrations:

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

Complete example integrating CommBus, llm_core, and storage:

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
    {:ok, stored_entries} = Storage.list_entries(
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
