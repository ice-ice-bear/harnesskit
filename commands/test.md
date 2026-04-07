---
description: Run project tests with HarnessKit integration — logs failures to failures.json automatically
user_invocable: true
---

# /harnesskit:test

Run the project's test suite and integrate results with HarnessKit failure tracking.

1. Read `.harnesskit/detected.json` to determine test framework
2. Run tests:
   - vitest: `npx vitest run`
   - jest: `npx jest`
   - pytest: `pytest -v`
   - go: `go test ./...`
3. If tests fail:
   - Append failures to `.harnesskit/current-session.jsonl`:
     `{"type":"error","pattern":"test failure message","file":"test file"}`
   - Show failure summary
4. If all tests pass:
   - Report success
