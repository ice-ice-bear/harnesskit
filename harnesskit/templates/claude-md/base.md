## Session Start Protocol
1. Read `progress/claude-progress.txt`
2. Read `docs/feature_list.json` — select highest priority `passes: false` feature
3. Write selected feature ID to `.harnesskit/current-feature.txt`
4. Run existing tests to verify baseline

## Session End Protocol
1. Update `progress/claude-progress.txt` with:
   - What was implemented this session
   - What is currently broken
   - What to focus on next session
2. Update `docs/feature_list.json` — set `passes: true` only after tests pass
3. Commit changes

## Error Logging (automatic)
- On error: append to `.harnesskit/current-session.jsonl`:
  `{"type":"error","pattern":"error message","file":"file path"}`
- On feature complete: `{"type":"feature_done","id":"feat-XXX"}`
- On feature fail: `{"type":"feature_fail","id":"feat-XXX"}`

## Tool Usage Logging (v2a — automatic)
- On major tool use, append to `.harnesskit/current-session.jsonl`:
  `{"type":"tool_call","tool":"ToolName","summary":"brief description","timestamp":"HH:MM"}`
  ※ Log Bash, Edit, Write, WebSearch, WebFetch only (skip Read, Glob, Grep)
  ※ One line per tool call, keep summary under 50 chars
- On marketplace plugin use:
  `{"type":"plugin_invocation","plugin":"plugin-name","feedback":["slug-keyword"]}`
  ※ feedback slugs: lowercase, hyphens, no spaces. Example: "missing-error-boundary"
  ※ Reuse existing slugs from prior session logs when same concept applies

## Absolute Rules
- Do NOT modify `feature_list.json` except the `passes` field
- One feature per session
- Never set `passes: true` without passing tests
