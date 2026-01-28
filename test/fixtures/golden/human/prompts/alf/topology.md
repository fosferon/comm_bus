---
slug: alf/topology
description: "Categorize task topology and domain semantics"
---
You are categorizing a task's TOPOLOGY and DOMAIN at a semantic level.

This determines what KIND of solution is appropriate before writing any code.

TOPOLOGY (where/how it runs):

connectivity:
  - none: no network needed
  - local: localhost/loopback only
  - network: LAN/internal services
  - internet: external APIs/services

processing:
  - pure: no state, same input → same output
  - stateful: maintains state between operations
  - distributed: coordinates across processes/machines

storage:
  - none: in-memory only
  - filesystem: reads/writes local files
  - database: queries/mutates database
  - remote: cloud storage, external APIs

execution:
  - sync: run to completion, return result
  - async: fire and forget, callback later
  - streaming: continuous input/output flow

side_effects:
  - none: pure computation
  - local: modifies local files/state
  - external: modifies external systems

DOMAIN (what kind of data/operation):

data_shape:
  - scalar: single value
  - record: structured object
  - collection: list/set of items
  - tree: hierarchical/nested
  - graph: interconnected nodes

operation:
  - transform: input → different output
  - validate: input → pass/fail
  - generate: nothing/seed → new content
  - analyze: input → insights/summary
  - mutate: modify existing state in place

boundaries:
  - closed: all input/output predetermined
  - open_input: accepts external/dynamic input
  - open_output: produces variable output
  - open_both: dynamic input and output

determinism:
  - pure: same input always → same output
  - deterministic: reproducible given same state
  - probabilistic: involves randomness/LLM

OUTPUT FORMAT (JSON):
```json
{
  "topology": {
    "connectivity": "none|local|network|internet",
    "processing": "pure|stateful|distributed",
    "storage": "none|filesystem|database|remote",
    "execution": "sync|async|streaming",
    "side_effects": "none|local|external"
  },
  "domain": {
    "data_shape": "scalar|record|collection|tree|graph",
    "operation": "transform|validate|generate|analyze|mutate",
    "boundaries": "closed|open_input|open_output|open_both",
    "determinism": "pure|deterministic|probabilistic"
  },
  "implications": [
    "what this means for the solution"
  ]
}
```

The implications should state what IS and ISN'T appropriate:
- "No HTTP client needed"
- "Must handle file I/O"
- "Solution must be idempotent"
- "Can use memoization"

Now categorize.
