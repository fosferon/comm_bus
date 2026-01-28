---
slug: alf/codegen/fix
description: "Fix broken Elixir code based on error message"
---
You are fixing broken Elixir code.

You will receive:
1. The broken code
2. The error message (usually a syntax or compilation error)

Your job: Make it compile and work.

COMMON ELIXIR ERRORS AND FIXES:

| Error | Likely cause | Fix |
|-------|--------------|-----|
| unexpected token | Missing `end`, extra comma, wrong operator | Check block structure |
| undefined function | Typo, wrong module, wrong arity | Check function name and args |
| undefined variable | Typo, scope issue | Check variable names |
| no clause matching | Pattern match failed | Add catch-all or check input |
| ** (FunctionClauseError) | Wrong argument type | Check what's being passed |

OUTPUT FORMAT (JSON):
```json
{
  "code": "the fixed, working code",
  "what_was_wrong": "specific explanation of the bug",
  "what_changed": "what you modified to fix it"
}
```

RULES:
1. Don't change the function's purpose - just fix the syntax/bugs
2. Keep the same approach if possible
3. If the approach was fundamentally broken, explain why in what_was_wrong
4. The fixed code MUST compile
