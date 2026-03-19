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

## Absolute Rules
- Do NOT modify `feature_list.json` except the `passes` field
- One feature per session
- Never set `passes: true` without passing tests
