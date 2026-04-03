# CommBus Architecture

## What CommBus Is

CommBus is a database-agnostic context assembly engine for LLM interactions. It sits between an application's conversation state and its LLM provider, solving the problem of dynamically injecting relevant context into prompts while respecting token budgets. Applications define context **entries** with keywords and priorities; CommBus matches those entries against conversation history, fits them within per-section token budgets, and produces a structured **packet** of messages ready for any LLM provider.

---

## Core Data Model

### Entry

An `Entry` (`CommBus.Entry`) is the atomic unit of injectable context. Each entry carries:

| Field | Type | Purpose |
|-------|------|---------|
| `id` | `term()` | Unique identifier |
| `content` | `String.t()` | The text injected into the prompt |
| `keywords` | `[String.t()]` | Trigger words/phrases for matching |
| `priority` | `integer()` | Higher priority = selected first during budget fitting |
| `weight` | `integer()` | Secondary sort key and section ordering multiplier |
| `token_count` | `non_neg_integer()` | Pre-computed or auto-annotated token cost |
| `mode` | `:constant \| :triggered` | Whether the entry is always included or keyword-gated |
| `match_mode` | `:any \| :all` | Whether any keyword or all keywords must match |
| `match_strategy` | `:exact \| :fuzzy \| :semantic` | How keywords are compared to text |
| `section` | `:system \| :pre_history \| :history \| :post_history` | Target section in the assembled prompt |
| `enabled` | `boolean()` | Master on/off switch |
| `exclude_keywords` | `[String.t()]` | Negative keywords that block the entry |
| `scan_depth` | `pos_integer() \| nil` | How many recent messages to scan |
| `cooldown_turns` | `non_neg_integer() \| nil` | Minimum turns between re-injection |
| `match_threshold` | `number() \| nil` | Minimum match score to qualify |
| `fuzzy_threshold` | `number() \| nil` | Jaro-distance threshold for fuzzy matching |
| `semantic_hints` | `[String.t()]` | Alternative hints for semantic matching |
| `semantic_threshold` | `number() \| nil` | Cosine-similarity floor for semantic matching |

### Packet

A `Packet` (`CommBus.Protocol.Packet`) is the canonical output of the assembly pipeline:

- **`messages`** — Flat list of role/content maps ready for an LLM provider.
- **`sections`** — Messages grouped by section (`:system`, `:pre_history`, `:history`, `:post_history`).
- **`included_entries`** — Entries that were selected and fit within budget.
- **`excluded_entries`** — Entries that were dropped (budget, no match, disabled, etc.).
- **`token_usage`** — Per-section and total token accounting.
- **`metadata`** — Adapter info, generation timestamp, section-role mapping.

### Section

Sections partition the prompt into logical regions:

| Section | Role | Purpose |
|---------|------|---------|
| `:system` | System instructions | Persona, rules, constraints |
| `:pre_history` | Context before conversation | Injected knowledge, methodology entries |
| `:history` | Conversation messages | User/assistant message history |
| `:post_history` | Context after conversation | Recent reminders, output formatting |

Each section competes for its own share of the token budget. The `Budget.Planner` allocates tokens across sections using configurable ratios (defaults: system 10%, pre_history 30%, history 40%, post_history 20%).

### Budget

Budget is not a struct — it is a map produced by `CommBus.Budget.Planner.plan/1`:

```elixir
%{
  total: 8000,
  completion: 2000,
  sections: %{
    system: 600,
    pre_history: 1800,
    history: 2400,
    post_history: 1200
  }
}
```

The `total` is the model's context window. The `completion` reserve is subtracted first. The remainder is divided across sections by ratio. Within each section, `Budget.fit_budget/2` performs priority-based greedy selection.

---

## Entry Modes and Match Strategies

### Modes

- **`:constant`** — Always included in the assembly regardless of conversation content. Used for system instructions, persona definitions, and fixed context.
- **`:triggered`** — Only included when keywords match against recent conversation messages. Used for domain-specific knowledge, conditional instructions, and contextual guidance.

### Match Strategies

- **`:exact`** — Word-boundary matching with support for:
  - Simple words: `"auth"` matches `\bauth\b` (case-insensitive)
  - Wildcards: `"auth*"` matches any word starting with `auth`
  - Phrases: `"two words"` matches the exact substring
- **`:fuzzy`** — Jaro-distance similarity between keyword tokens and message tokens. Controlled by `fuzzy_threshold` (default 0.85).
- **`:semantic`** — Pluggable similarity via the `CommBus.Semantic.Adapter` behaviour. The default `SimpleAdapter` uses Jaccard token overlap. Controlled by `semantic_threshold` (default 0.75) and optional `semantic_hints`.

### Match Modes

- **`:any`** (default) — Entry matches if **any** keyword hits. Score is averaged across matched keywords.
- **`:all`** — Entry matches only if **every** keyword hits. Score is zero if any keyword is missing.

### Advanced Matching Features

- **Negative keywords** (`exclude_keywords`): Block an entry if any negative keyword appears.
- **Cooldown** (`cooldown_turns`): Prevent re-injection for N turns after last injection.
- **Scan depth** (`scan_depth`): Limit keyword scanning to the N most recent messages.
- **IDF weighting**: Keywords shared by fewer entries receive higher match weight.
- **Recency decay**: More recent message matches score higher (configurable decay factor).

---

## The Builder Pipeline

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                          CommBus Assembly Pipeline                               │
│                                                                                  │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐    ┌───────────────┐  │
│  │   Sources    │───▶│   Matcher    │───▶│    Budget     │───▶│    Packet     │  │
│  │             │    │              │    │    Fitting    │    │   Builder    │  │
│  └─────────────┘    └──────────────┘    └───────────────┘    └───────────────┘  │
│                                                                                  │
│  Entries from:       Keyword scan       Priority-based       Sections →          │
│  • Storage adapter   Fuzzy matching     greedy selection     Messages            │
│  • Methodologies     Semantic sim.      Per-section caps     Role mapping        │
│  • Direct input      Score + filter     Token accounting     Metadata            │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Step-by-step flow

1. **Entry collection** — Constant and triggered entries arrive from storage adapters, YAML methodologies, or direct input. Methodology refs are resolved via `CommBus.Methodologies.entries_for/1`.

2. **Partitioning** — `Context.plan/3` separates entries into constants (always included), triggered candidates (need matching), and immediately excluded (disabled entries).

3. **Matching** — `Matcher.match_entries/3` scans recent conversation messages against triggered entries. Each match produces a `MatchResult` with score, matched keywords, and diagnostic reasons. Entries below their `match_threshold` are excluded.

4. **Deduplication** — Duplicate entries (same `id` + `content`) are removed.

5. **Token annotation** — `Tokenizer.annotate_entries/2` fills in `token_count` for any entry that doesn't already have one.

6. **Budget planning** — If a `:budget` option with `:plan` key is provided, `Budget.Planner.plan/1` computes per-section allocations. Otherwise, explicit section budgets or a flat total are used directly.

7. **Budget fitting** — Within each section, `Budget.fit_budget/2` sorts entries by `(priority, weight, id)` descending and greedily selects entries until the section's token cap is reached. Entries that don't fit are excluded with `:section_budget` or `:total_budget` reason.

8. **Section positioning** — Selected entries are grouped by section and sorted by `(weight, priority)` within each section.

9. **Packet construction** — The `LlmCoreAdapter` (or custom adapter) converts sections into a flat message list with appropriate roles:
   - `:system` and `:pre_history` entries → system messages (before history)
   - `:history` → conversation messages in original order
   - `:post_history` entries → system messages (after history)

10. **Validation** — `Protocol.Validator.validate/1` checks message structure, section integrity, and token usage before the packet is returned.

11. **Telemetry** — Events are emitted at `[:comm_bus, :context, :plan]` (span) and `[:comm_bus, :context, :metrics]` (inclusion rate, budget waste, counts).

---

## Token Budgeting

### How Sections Compete for Budget

The total token budget represents the model's context window minus a completion reserve. The remaining tokens are distributed across sections by ratio:

```
Total: 8000 tokens
  └─ Completion reserve: 2000 (25%)
  └─ Available for context: 6000
       ├─ system:       600  (10%)
       ├─ pre_history: 1800  (30%)
       ├─ history:     2400  (40%)
       └─ post_history: 1200  (20%)
```

Ratios are configurable via `Budget.Planner.plan/1`:

```elixir
Budget.Planner.plan(
  total: 8000,
  completion: 2000,
  section_ratios: %{system: 0.15, pre_history: 0.25, history: 0.40, post_history: 0.20}
)
```

### Greedy Selection Within Sections

Within each section, `Budget.fit_budget/2` implements a greedy algorithm:

1. Sort entries by `(priority DESC, weight DESC, id)`.
2. Iterate in order; include an entry if its `token_count` fits within the remaining section budget.
3. Skip entries that would exceed the cap.

This is a classic greedy knapsack — fast, deterministic, and predictable. High-priority entries always get first claim on budget.

### Budget Waste Tracking

The telemetry layer tracks `budget_waste` — the difference between allocated budget and actually used tokens. High waste indicates over-provisioned sections or under-populated entry sets.

---

## Methodology Loading

Methodologies are curated prompt packs stored as YAML files. They let teams share reusable context entry sets.

### YAML → Entry Structs

```
config/comm_bus/methodologies/
  ├── bug_triage.yml
  └── root_cause.yml
```

Each YAML file defines:

```yaml
name: "Bug Triage"
slug: "bug_triage"
description: "Structured bug analysis framework"
tags: ["bugs", "analysis"]
entries:
  - id: "severity-check"
    content: "Evaluate severity using..."
    keywords: ["bug", "error", "crash"]
    section: pre_history
    mode: triggered
    priority: 80
```

`CommBus.Methodologies.load_from_disk!/1` parses all YAML files, validates schema, builds `Entry` structs, and caches the catalog in `:persistent_term`. At runtime, `entries_for("bug_triage")` returns the full entry list; `entries_for("bug_triage#severity-check")` returns a specific entry by ID.

---

## Key Extension Points

### Source Behaviour (Storage Adapters)

Two behaviours define storage:

- **`CommBus.Storage.EntryStore`** — `store_entry/1`, `list_entries/1`, `get_entry/1`, `delete_entry/1`
- **`CommBus.Storage.ConversationStore`** — `store_conversation/1`, `load_conversation/1`, `update_conversation/2`

Built-in implementations:

| Adapter | Backend | Use case |
|---------|---------|----------|
| `Storage.InMemory` | ETS tables | Testing, prototyping |
| `Storage.Ecto` | Any Ecto repo | Generic production use |
| `Storage.DevMan` | DevMan SQLite | DevMan integration |
| `Storage.HuMan` | HuMan PostgreSQL | HuMan integration |

Custom adapters implement the behaviours and are configured via application env.

### Template Engine

The `CommBus.Template.Engine` behaviour defines a single callback:

```elixir
@callback render(String.t(), map(), keyword()) ::
  {:ok, RenderResult.t()} | {:error, RenderError.t()}
```

Two engines ship with CommBus:

- **`BbMustache`** — Wraps Erlang's `:bbmustache` library. Default engine.
- **`ExMustache`** — Wraps the pure-Elixir `ExMustache` library.

Both support: variable interpolation, sections, inverted sections, partials, `{{#if}}`/`{{#unless}}`/`{{#each}}` control tags (rewritten to Mustache-native syntax), default values (`{{var | default: "fallback"}}`), and type coercion from YAML frontmatter declarations.

### Tokenizer

The `CommBus.Tokenizer` behaviour defines:

```elixir
@callback count_tokens(String.t(), keyword()) :: non_neg_integer()
@callback count_message(Message.t(), keyword()) :: non_neg_integer()
```

The bundled `Tokenizer.Simple` uses a heuristic word/punctuation count. Applications can plug in a real tokenizer (e.g., tiktoken via NIF) by implementing the behaviour and setting it in config.

### Semantic Adapter

The `CommBus.Semantic.Adapter` behaviour:

```elixir
@callback similarity(Entry.t(), String.t(), String.t(), keyword()) :: number()
```

The default `SimpleAdapter` uses Jaccard token-set overlap. Applications can plug in embedding-based similarity by implementing this behaviour.

### Protocol Adapter

The `CommBus.Protocol.Adapter` behaviour:

```elixir
@callback assemble(Context.t()) :: {:ok, Packet.t()} | {:error, term()}
```

The `LlmCoreAdapter` is the default, producing packets compatible with the `llm_core` library. Custom adapters can transform the assembly into any downstream format.

---

## Entry Flow Diagram

```
                        ┌─────────────────────┐
                        │    Entry Sources     │
                        │                      │
                        │  Storage adapters    │
                        │  YAML methodologies  │
                        │  Direct input        │
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │     Partition        │
                        │                      │
                        │  Constants ──────────┼──── always included
                        │  Triggered ──────────┼──── need matching
                        │  Disabled  ──────────┼──── excluded
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │   Keyword Matcher    │
                        │                      │
                        │  Exact / Fuzzy /     │
                        │  Semantic matching   │
                        │  IDF weighting       │
                        │  Recency decay       │
                        │  Cooldown / Negative │
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │  Dedup + Annotate    │
                        │                      │
                        │  Remove duplicates   │
                        │  Count tokens        │
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │   Budget Fitting     │
                        │                      │
                        │  Plan section caps   │
                        │  Greedy selection    │
                        │  per (priority,wt)   │
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │   Packet Assembly    │
                        │                      │
                        │  Section → Role map  │
                        │  Entry → Message     │
                        │  History insertion   │
                        │  Validation          │
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │   LLM Provider       │
                        │                      │
                        │  [system msg]        │
                        │  [pre_history msgs]  │
                        │  [conversation msgs] │
                        │  [post_history msgs] │
                        └─────────────────────┘
```

---

## Telemetry Events

| Event | Type | Measurements |
|-------|------|-------------|
| `[:comm_bus, :context, :plan]` | Span | Duration |
| `[:comm_bus, :context, :metrics]` | Execute | `inclusion_rate`, `budget_waste`, `included_count`, `candidate_count`, `used_tokens`, `budget_total` |

---

## Configuration Reference

```elixir
config :comm_bus,
  # Template engine for Mustache rendering
  template_engine: CommBus.Template.Engine.BbMustache,

  # Token counting implementation
  tokenizer: CommBus.Tokenizer.Simple,

  # Semantic similarity adapter
  semantic_adapter: CommBus.Semantic.SimpleAdapter,

  # Prompt file directory (for Prompts catalog)
  prompt_root: "config/comm_bus/prompts",

  # Methodology YAML directory
  methodology_root: "config/comm_bus/methodologies",

  # Prompt override store (for A/B testing, per-user overrides)
  prompt_override_store: CommBus.Prompts.OverrideStore.Noop,

  # Storage adapters
  entry_store: CommBus.Storage.InMemory,
  conversation_store: CommBus.Storage.InMemory
```
