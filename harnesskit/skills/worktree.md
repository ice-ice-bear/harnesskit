---
name: worktree
description: Create a harness-aware git worktree for isolated feature work using Claude Code's built-in worktree
user_invocable: true
---

# /harnesskit:worktree

Create an isolated worktree for a specific feature, syncing harness files for session continuity.

## Usage

```
/harnesskit:worktree feat-007
```

Takes a feature ID from `docs/feature_list.json`.

## Prerequisites

- `.harnesskit/config.json` must exist (HarnessKit initialized)
- `docs/feature_list.json` must contain the specified feature ID

## Instructions — Enter

1. Validate the feature ID exists in `docs/feature_list.json`
   - If not found: "Feature '{id}' not found in feature_list.json. Available: {list ids}"

2. Invoke Claude Code's built-in worktree creation (use EnterWorktree tool)

3. Sync harness files to the new worktree (only non-git-tracked files):
   - Copy `.harnesskit/` directory (config.json, detected.json, failures.json, insights-history.json, session-logs/)
   - ※ CLAUDE.md, .claudeignore, docs/feature_list.json, progress/ are git-tracked — already in worktree

4. Set `.harnesskit/current-feature.txt` to the specified feature ID

5. Output:
   ```
   🌲 Worktree ready for {feature_id}: {feature_description}
      Harness files synced.

      When done, sync data back before exiting:
      1. Copy .harnesskit/session-logs/*.json back to main
      2. Merge .harnesskit/failures.json with main (new failures: add, existing: sum occurrences)
      3. Update docs/feature_list.json passes field if feature completed
      4. Use ExitWorktree to return
   ```

## Instructions — Exit (Data Sync)

Before calling ExitWorktree, sync harness data back to main:

1. **Session logs**: Copy `.harnesskit/session-logs/*.json` from worktree to main's `.harnesskit/session-logs/` (append, no overwrite — filenames are timestamp-based)

2. **Failures**: Merge `.harnesskit/failures.json`:
   - New failures (pattern not in main): add to main
   - Existing failures (same pattern): sum occurrences, update lastSeen

3. **Current session**: Move `.harnesskit/current-session.jsonl` to main if exists

4. **Feature list**: For any feature where `passes` changed from `false` to `true`, update main's `docs/feature_list.json` (one-way: only false→true)

5. **Progress**: Append worktree's `progress/claude-progress.txt` content to main's progress file

6. Output: "✅ Harness data synced to main. Exiting worktree."

7. Call ExitWorktree
