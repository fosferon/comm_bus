---
slug: alf/objective
description: "Define measurable success criteria before solving"
---
You are defining what SUCCESS looks like for a task.

Do NOT describe the process. Describe the END STATE.

Answer these questions:

1. PROOF: How do we know it worked?
   - What is measurable?
   - What command/check proves success?

2. BEFORE/AFTER: What changes?
   - What exists after that didn't before?
   - What is gone after that existed before?
   - What is different?

3. BOUNDARIES: What is in/out of scope?
   - What MUST happen?
   - What MUST NOT happen?
   - What is explicitly excluded?

OUTPUT FORMAT (JSON):
```json
{
  "objective": {
    "success_proof": "The command or check that proves completion",
    "before_state": "Description of state before task",
    "after_state": "Description of state after task",
    "must_happen": ["required outcome 1", "required outcome 2"],
    "must_not_happen": ["forbidden outcome 1"],
    "out_of_scope": ["explicitly excluded thing"]
  }
}
```

RULES:
- Be concrete, not abstract
- Measurable, not subjective
- State, not process
- If success can't be verified, the objective is unclear

EXAMPLES:

Task: "Fix compilation warnings"
```json
{
  "objective": {
    "success_proof": "mix compile 2>&1 | grep -c warning returns 0",
    "before_state": "mix compile produces N warnings",
    "after_state": "mix compile produces 0 warnings",
    "must_happen": ["source files modified to eliminate warning causes"],
    "must_not_happen": ["behavior changes", "test failures", "new warnings introduced"],
    "out_of_scope": ["dialyzer warnings", "credo suggestions", "formatting"]
  }
}
```

Task: "Deploy to production"
```json
{
  "objective": {
    "success_proof": "curl https://app.example.com/health returns 200",
    "before_state": "old version running or no version running",
    "after_state": "new version running and responding",
    "must_happen": ["health check passes", "logs show startup complete"],
    "must_not_happen": ["downtime > 30s", "data loss", "rollback triggered"],
    "out_of_scope": ["DNS changes", "SSL renewal"]
  }
}
```

Now define the objective.
