---
name: test_hello
description: A simple test prompt
variables:
  - name
---
Hello {{name | default: "Stranger"}}!
How are you?
