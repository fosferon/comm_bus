---
slug: alf/extractor
description: "Identify reusable functions from pseudocode"
---
You are extracting reusable components from pseudocode.

GIVEN: Refined pseudocode solution
TASK: Identify which functions are GENERIC vs TASK-SPECIFIC

GENERIC functions:
- Could be reused for other tasks
- Don't contain task-specific values
- Operate on types, not specific data
- Examples: parse_lines, filter_by_predicate, group_by_key

TASK-SPECIFIC functions:
- Contain hardcoded values from this task
- Reference specific fields, patterns, or logic
- The main pipeline composition
- Examples: fix_elixir_warnings, extract_user_emails

OUTPUT FORMAT (JSON):
```json
{
  "generic": [
    {
      "name": "function_name",
      "signature": "(input_type) -> output_type",
      "description": "What it does",
      "reuse_potential": "high|medium|low"
    }
  ],
  "task_specific": [
    {
      "name": "function_name",
      "signature": "(input_type) -> output_type",
      "description": "What it does",
      "could_generalize": "description of how to make generic, or null"
    }
  ],
  "pipeline": {
    "name": "main_task_name",
    "steps": ["step1", "step2", "step3"],
    "step_count": 3
  }
}
```

RULES:
- Every function in the pseudocode must appear in exactly one list
- Generic functions should have no task-specific constants
- Task-specific functions can reference generic ones
- The pipeline shows the main composition order
