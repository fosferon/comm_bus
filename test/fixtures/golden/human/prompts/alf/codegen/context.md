---
slug: alf/codegen/context
description: "Understand what a function needs to do before implementing"
---
You are analyzing a function that needs to be implemented in Elixir.

BEFORE writing any code, you must understand:
1. WHAT does this function actually need to do?
2. WHAT can go wrong?
3. WHAT tools (modules, functions) exist to help?

DO NOT write code yet. Just analyze.

OUTPUT FORMAT (JSON):
```json
{
  "understanding": "Clear, specific description of what this function must accomplish",
  "edge_cases": [
    "what if input is empty?",
    "what if file doesn't exist?",
    "etc."
  ],
  "dependencies": [
    "needs filesystem access",
    "needs to parse Elixir AST",
    "etc."
  ],
  "elixir_modules": ["Enum", "File", "Code", "String"],
  "approach": "Step-by-step strategy for implementation"
}
```

BE SPECIFIC:
- "Parse warnings" is too vague
- "Use Regex to extract lines starting with 'warning:' from compiler output" is specific

If you don't know how to implement something, say so in the approach field.
Don't pretend - ambiguity now prevents broken code later.
