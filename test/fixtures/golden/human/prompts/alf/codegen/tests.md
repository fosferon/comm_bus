---
slug: alf/codegen/tests
description: "Generate test cases BEFORE implementation (TDD)"
---
You are writing test cases for an Elixir function BEFORE the implementation exists.

These tests ARE the specification. The code must pass them.

OUTPUT FORMAT (JSON):
```json
{
  "test_cases": [
    {
      "name": "test_basic_case",
      "input": "\"hello\"",
      "expected": "\"HELLO\"",
      "description": "Basic input returns uppercase"
    }
  ],
  "setup_code": null
}
```

RULES FOR TEST CASES:

1. **input** - Valid Elixir expression(s) for function arguments
   - Single arg: `"\"hello\""` or `"123"` or `"[1, 2, 3]"`
   - Multiple args: `"\"hello\", \"world\""` (comma-separated)
   - Must be valid Elixir that `Code.eval_string` can parse

2. **expected** - Valid Elixir expression for the return value
   - Must be exact, comparable values
   - `"true"` not `"returns true"`
   - `"[\"a\", \"b\"]"` not `"a list"`

3. **Coverage** - Include tests for:
   - Normal/happy path (at least 2)
   - Edge cases (empty input, nil, boundaries)
   - Error conditions if applicable

4. **Be concrete** - Use real values, not descriptions
   - GOOD: `{"input": "\"warning: x is unused\"", "expected": "true"}`
   - BAD: `{"input": "a warning message", "expected": "should be true"}`

5. **Test names** - Use snake_case, start with `test_`

EXAMPLES:

For a function that checks if a string contains "warning:":
```json
{
  "test_cases": [
    {"name": "test_with_warning", "input": "\"warning: foo\"", "expected": "true", "description": "Returns true when warning present"},
    {"name": "test_without_warning", "input": "\"all good\"", "expected": "false", "description": "Returns false when no warning"},
    {"name": "test_empty_string", "input": "\"\"", "expected": "false", "description": "Empty string has no warning"},
    {"name": "test_warning_in_middle", "input": "\"some warning: here\"", "expected": "true", "description": "Finds warning anywhere in string"}
  ]
}
```

For a function that takes two args (a, b) and returns their sum:
```json
{
  "test_cases": [
    {"name": "test_positive_numbers", "input": "2, 3", "expected": "5", "description": "Adds positive numbers"},
    {"name": "test_with_zero", "input": "5, 0", "expected": "5", "description": "Adding zero returns same number"},
    {"name": "test_negative", "input": "-1, -2", "expected": "-3", "description": "Handles negative numbers"}
  ]
}
```
