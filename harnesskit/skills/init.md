---
name: init
description: Generate harness infrastructure and toolkit files based on detection results and preset selection
---

# HarnessKit Init

Generate all harness files after detection and preset selection. Read `.harnesskit/detected.json` and `.harnesskit/config.json` to determine what to create.

## Generation Steps

### 1. Harness Infrastructure

Based on detected framework and preset, generate:

1. **CLAUDE.md** — compose from templates:
   - Always include: `templates/claude-md/base.md`
   - Add framework template: `templates/claude-md/{framework}.md` (or generic.md)
   - Apply preset filter: full/concise/minimal detail level
   - Keep under 60 lines (Lazy Loading principle)

2. **.claudeignore** — copy from `templates/claudeignore/{language}.txt` (or generic.txt)
   - Map: typescript/javascript → nextjs.txt, python → python.txt, others → generic.txt

3. **docs/feature_list.json** — copy from `templates/feature-list/starter.json`

4. **progress/claude-progress.txt** — create with initial content:
   ```
   # Claude Progress
   ## Session 1
   - HarnessKit initialized
   - No features implemented yet
   ```

5. **.harnesskit/failures.json** — create empty: `{"failures": []}`

6. **.harnesskit/insights-history.json** — create empty: `{"history": []}`

### 2. Register Hooks in .claude/settings.json

Merge HarnessKit hooks into existing `.claude/settings.json`:
- SessionStart: `session-start.sh`
- PreToolUse: `guardrails.sh`
- Stop: `session-end.sh`
- PostToolUse: `post-edit-lint.sh`, `post-edit-typecheck.sh` (if preset enables)
- PreToolUse: `pre-commit-test.sh` (if preset enables)

Preserve any existing hooks (append to arrays).

### 3. Skills via /skill-builder ("Curate, Don't Reinvent")

For each skill needed based on detected framework:
1. Check if a suitable marketplace skill plugin exists → recommend installation
2. If not available: load seed template from `templates/skills/{framework}/`
3. Pass seed + detected.json to `/skill-builder` for project-customized generation
4. Save to `.harnesskit/skills/`
5. Add reference to CLAUDE.md

### 4. Agent Recommendations

Present available agents from `templates/agents/`:
```
🤖 Recommended Agents:
  [1] planner — Implementation planning before coding
  [2] reviewer — Code review (or use marketplace /review)
  [3] researcher — API docs and library research
  [4] debugger — Error analysis and fix suggestions

  Install which? (1,2,3,4 / all / none):
```

Copy selected agents to `.harnesskit/agents/`.

### 5. Marketplace Recommendations

Based on detected.json, recommend marketplace plugins:
- All projects: `/simplify`
- Git remote detected: `/review`
- API project (fastapi/nextjs api routes): `/security-review`

### 6. Summary

Output a summary of everything created:
```
✅ HarnessKit initialized!

📁 Files created:
  - CLAUDE.md ({line_count} lines, {framework} + {preset})
  - .claudeignore ({pattern_count} patterns)
  - docs/feature_list.json (empty, ready to fill)
  - progress/claude-progress.txt (initialized)
  - .harnesskit/ (config, failures, insights-history)

🛠 Toolkit:
  - Skills: {list of installed skills}
  - Dev Hooks: {list of active hooks}
  - Commands: /harnesskit:test, :lint, :typecheck, :dev
  - Agents: {list of installed agents}

📦 Recommended plugins:
  - /simplify — install with: claude plugin install simplify

🚀 Next: Add features to docs/feature_list.json and start coding!
```
