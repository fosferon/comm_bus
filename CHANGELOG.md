# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-07-02

### Added

#### Axis
- **`CommBus.Axis`** - Generic per-entry classification axis registry. Lets consuming applications declare a named per-entry dimension (with a value domain and a default) and resolve it per entry. Axis values are stored in the existing `CommBus.Entry.metadata/0` bag — no struct or schema change. The registry is `persistent_term`-backed (mirroring `CommBus.Protocol.SectionRoles`) with `declare/2`, `get/2`, `get!/2`, `spec/1`, `declared/0`, `delete/1`, and `reset/0`. String metadata keys/values (as loaded from yml) are normalized to the declared atom domain; illegal stored values surface as `{:error, {:invalid_value, axis, raw}}` rather than being silently coerced. The data-plane read path uses `String.to_existing_atom/1` to guarantee out-of-domain (and potentially attacker-controlled) metadata values cannot grow the VM atom table. Fully additive and backward compatible — no axis declared means no behavior change. comm_bus ships the mechanism only; consumers own the vocabularies.

### Changed

#### Documentation
- Rewrote the Integration Guide and Adoption Guide to remove references to
  internal companion projects and to non-shipped storage adapters. Custom
  storage integration now documents the real `CommBus.Storage.EctoAdapter`
  plus the `CommBus.Storage.EntryStore` / `ConversationStore` behaviours that
  any application adopts against its own data store.
- Fixed a misleading doc comment in `CommBus.Storage.EctoAdapter` that named a
  module not present in the package.
- Added `CommBus.Axis` to the README and to the ExDoc module grouping.

## [0.1.0] - 2026-01-28

### Added

#### Core Assembly System
- **Assembler** - Core prompt assembly orchestration with keyword-triggered context injection
- **Matcher** - Keyword trigger detection supporting wildcards (`auth*`), phrases (`"two words"`), word boundaries, and semantic similarity foundation
- **Budget** - Token constraint fitting using priority-based greedy selection algorithm
- **Budget.Planner** - Intelligent section budget allocation (default: system 10%, pre_history 30%, history 40%, post_history 20%)

#### Template Engine
- Template rendering via Mustache engines (BbMustache and ExMustache support)
- YAML frontmatter parsing for prompt metadata
- Template loader with validation
- Prompt catalog system with persistent_term caching for performance
- File system watcher for automatic prompt reloading during development
- Prompt override system for runtime customization

#### Protocol & Pipeline
- ALF-based assembly pipeline for composable prompt processing
- Protocol packet format for canonical assembly output
- LLM Core adapter for seamless integration with llm_core library
- Provider message conversion supporting multiple LLM formats

#### Storage Adapters
- **InMemory** - Fast in-memory storage for testing and development
- **EctoAdapter** - Generic Ecto-based storage for production use
- **DevMan** - SQLite-backed storage adapter for DevMan workflow integration
- **HuMan** - PostgreSQL-backed storage adapter for HuMan reasoning infrastructure

#### Methodologies System
- YAML-based methodology definitions for reusable prompt packs
- Built-in methodologies:
  - `bug_triage` - Structured bug analysis and prioritization framework
  - `root_cause` - Root cause analysis methodology
- Methodology composition and filtering (e.g., `"bug_triage#step-1"`)
- Support for tags, sections, and priority configuration

#### Semantic Matching
- Semantic matching adapter interface for extensible similarity detection
- Simple semantic matcher implementation as baseline
- Foundation for ML-based semantic search integration

#### Mix Tasks (CLI)
- `mix comm_bus.entries` - List and filter entries by storage, mode, enabled state
- `mix comm_bus.budget` - Simulate budget allocation for conversation/entries YAML files
- `mix comm_bus.simulate` - Full assembly simulation with detailed output
- `mix comm_bus.compare_engines` - Compare BbMustache vs ExMustache rendering
- `mix comm_bus.sync_fixtures` - Synchronize golden test fixtures

#### Testing & Fixtures
- Comprehensive test suite with 100+ tests
- Golden template fixtures for DevMan and HuMan adapters
- Property-based testing with StreamData
- Assembly integration tests
- Template consistency validation

#### Observability
- Telemetry integration for assembly operations
- Event emissions for:
  - Assembly start/stop/exception
  - Budget planning
  - Template rendering
  - Storage operations
- Telemetry metrics support

#### Data Structures
- **Entry** - Injectable context with keywords, priority, weight, section, and mode
- **Message** - OpenAI-compatible message format (system/user/assistant/tool roles)
- **Conversation** - Session state with message history, depth, and metadata
- **Packet** - Assembly output with sectioned messages, token usage, and exclusion details
- **Context** - Rich context structure for template rendering

#### Documentation
- Module documentation with @moduledoc for all public modules
- Function specifications with @spec for type safety
- Inline examples and usage patterns
- CLAUDE.md internal reference guide

[Unreleased]: https://github.com/[username]/comm_bus/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/[username]/comm_bus/releases/tag/v0.1.0
