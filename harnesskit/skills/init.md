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

7. **v2a fields in .harnesskit/config.json** — if `schemaVersion` is missing or < "2.0", add:
   - `schemaVersion`: `"2.0"`
   - `uncoveredAreas`: populated during marketplace plugin discovery (areas with no matching plugin)
   - `reviewInternalization`: `{"stage": "marketplace_only", "supplementSince": null, "coveragePercent": null}`
   - `customHooks`: `[]`
   - `customSkills`: `[]`
   - `customAgents`: `[]`
   - `removedPlugins`: `[]`

### 2. Register Hooks in .claude/settings.json

Merge HarnessKit hooks into existing `.claude/settings.json`:
- SessionStart: `session-start.sh`
- PreToolUse: `guardrails.sh`
- Stop: `session-end.sh`
- PostToolUse: `post-edit-lint.sh`, `post-edit-typecheck.sh` (if preset enables)
- PreToolUse: `pre-commit-test.sh` (if preset enables)

Preserve any existing hooks (append to arrays).

### 3. Marketplace Plugin Discovery ("Curate, Don't Reinvent")

Search the Claude Code marketplace for plugins matching the detected project:

**Skills:**
1. Search for framework-specific skill plugins (e.g., Next.js conventions, Python testing)
2. Search for common skill plugins (e.g., code style, git workflow, TypeScript standards)
3. Recommend and install matching plugins directly — do NOT create custom skills at init time
4. If marketplace has nothing for a critical gap: note it for future `/harnesskit:insights` to address via `/skill-builder`

**Agents:**
1. Search for agent plugins matching project needs (e.g., planner, reviewer, debugger, researcher)
2. Recommend and install matching plugins directly — do NOT use built-in templates
3. For code review: prefer well-established marketplace plugins (e.g., `/review`)

**General recommendations** based on detected.json:
- All projects: `/simplify`
- Git remote detected: `/review`
- API project (fastapi/nextjs api routes): `/security-review`

Present all recommendations together:
```
📦 Marketplace Plugins for {framework} project:

  Skills:
    [1] plugin-name — description (install? y/n)
    [2] plugin-name — description (install? y/n)

  Agents:
    [3] plugin-name — description (install? y/n)
    [4] plugin-name — description (install? y/n)

  General:
    [5] /simplify — code quality (install? y/n)
    [6] /review — code review (install? y/n)
```

Customization happens later: as `/harnesskit:insights` detects usage patterns and error rates,
it proposes project-specific skill/agent creation or customization via `/skill-builder`.

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

### Migration from v1

If `.harnesskit/config.json` exists but has no `schemaVersion` or `schemaVersion < "2.0"`:
1. This is a v1 project upgrading to v2a
2. Do NOT re-run full setup — preserve all existing data
3. Add missing v2a fields to existing config.json (non-destructive merge):
   - Add `schemaVersion: "2.0"`
   - Add `uncoveredAreas: []` (will be populated by next insights run)
   - Add `reviewInternalization: {"stage": "marketplace_only", "supplementSince": null, "coveragePercent": null}`
   - Add `customHooks: []`, `customSkills: []`, `customAgents: []`
   - Add `removedPlugins: []`
4. Update CLAUDE.md with v2a logging rules (append tool usage logging section from base.md template)
5. Output: "✅ Migrated to v2a schema. Existing data preserved."
