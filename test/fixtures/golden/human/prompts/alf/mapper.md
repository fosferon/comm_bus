---
slug: alf/mapper
description: "Map functions to droplet specifications"
---
You are converting pseudocode functions to executable droplet specifications.

GIVEN:
- Extracted functions (generic + task-specific)
- Original pseudocode for reference

TASK: Generate droplet specs for each function

DROPLET TYPES:
- "code": Pure Elixir function, deterministic, no LLM needed
- "shell": Executes shell command, captures output
- "prompt": Requires LLM judgment/creativity
- "http": Makes HTTP request
- "transform": Data transformation (map/filter/reduce)

OUTPUT FORMAT (JSON):
```json
{
  "droplets": [
    {
      "name": "function_name",
      "droplet_type": "code|shell|prompt|http|transform",
      "instruction": "What this droplet does",
      "input_schema": {
        "param_name": "type"
      },
      "output_schema": {
        "produces": "type"
      },
      "code": "# Elixir implementation or shell command",
      "confidence": 0.0-1.0
    }
  ],
  "groove": {
    "name": "task_name",
    "description": "What the groove accomplishes",
    "steps": [
      {
        "order": 1,
        "droplet_name": "step_one",
        "purpose": "Why this step exists"
      }
    ],
    "confidence": 0.0-1.0
  }
}
```

RULES FOR CODE GENERATION:
- Elixir syntax
- Pattern matching over conditionals
- Use Enum/Stream for collections
- Handle errors with {:ok, _} | {:error, _} tuples
- No external dependencies unless specified

RULES FOR SHELL DROPLETS:
- Single command or piped commands
- Capture both stdout and stderr
- Return string output

RULES FOR PROMPT DROPLETS:
- Include clear instruction for LLM
- Specify what context is needed
- No code field (executed by LLM)

CONFIDENCE SCORING:
- 1.0: Trivial implementation, high certainty
- 0.8: Standard pattern, well understood
- 0.5: Some ambiguity, may need refinement
- 0.3: Complex or uncertain, needs review
