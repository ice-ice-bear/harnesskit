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
   - Append bible reference line: `For harness engineering principles → .harnesskit/bible.md`
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

7. **v2a fields in .harnesskit/config.json** — if `schemaVersion` is missing or < "2.1", add:
   - `schemaVersion`: `"2.1"`
   - `uncoveredAreas`: populated during marketplace plugin discovery (areas with no matching plugin)
   - `reviewInternalization`: `{"stage": "marketplace_only", "supplementSince": null, "coveragePercent": null}`
   - `customHooks`: `[]`
   - `customSkills`: `[]`
   - `customAgents`: `[]`
   - `removedPlugins`: `[]`
   - `bibleInstalled`: `true`

8. **Bible reference** — copy `templates/bible.md` to `.harnesskit/bible.md`
   - This is a fixed reference document, not user-modifiable

### 2. Register Hooks in .claude/settings.json

Merge HarnessKit hooks into existing `.claude/settings.json`:

Hook commands use `${CLAUDE_PLUGIN_ROOT}` which is auto-substituted by Claude Code:
- SessionStart: `${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh`
- PreToolUse: `${CLAUDE_PLUGIN_ROOT}/hooks/guardrails.sh`
- Stop: `${CLAUDE_PLUGIN_ROOT}/hooks/session-end.sh`
- PostToolUse: `${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-lint.sh`, `${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-typecheck.sh` (if preset enables)
- PreToolUse: `${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit-test.sh` (if preset enables)

Preserve any existing hooks (append to arrays).

### 3. Marketplace Plugin Discovery ("Curate, Don't Reinvent")

Read the verified recommendations from `${CLAUDE_PLUGIN_ROOT}/templates/marketplace-recommendations.json`.

**If file exists and lastUpdated < 30 days:**
1. Match detected.json properties against recommendation conditions:
   - `language` field → lsp category (language-specific LSP plugin)
   - `git == true` → general/review plugins with "git" condition
   - `framework` matches api condition (fastapi, django, nextjs) → security plugins
   - Check `git remote -v` for github.com → github_remote condition
2. Present matched plugins for user selection

**If file missing or stale (> 30 days):**
1. Attempt live fetch from marketplace URL in the recommendations file
2. If fetch fails, use hardcoded minimal list:
   - code-simplifier@claude-plugins-official (always)
   - commit-commands@claude-plugins-official (if git)
   - code-review@claude-plugins-official (if git)

**Always append:**
"더 많은 플러그인은 `/plugin` → Discover 탭에서 탐색하세요."

**Present recommendations:**

    📦 Marketplace Plugins for {framework} project:

      LSP:
        [1] {lsp-plugin} — 코드 인텔리전스 (install? y/n)

      General:
        [2] code-simplifier — 코드 품질 리뷰 (install? y/n)
        [3] commit-commands — Git 커밋 워크플로우 (install? y/n)

      Review:
        [4] code-review — PR 리뷰 자동화 (install? y/n)

      Security:
        [5] semgrep — 보안 취약점 감지 (install? y/n)

      💡 More plugins: /plugin → Discover tab

Install approved plugins: `/plugin install {plugin-name}@claude-plugins-official`

Record installed plugins in `.harnesskit/config.json` → `installedPlugins` array.
Record unmatched areas in `config.json` → `uncoveredAreas` array.

### 4. Summary

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

### Migration from v2a

If `.harnesskit/config.json` has `schemaVersion: "2.0"`:
1. This is a v2a project upgrading to v2b
2. Copy `templates/bible.md` to `.harnesskit/bible.md`
3. Add bible reference to CLAUDE.md (append line)
4. Update config.json:
   - `schemaVersion`: `"2.1"`
   - `bibleInstalled`: `true`
5. Output: "✅ Migrated to v2b schema. Bible installed."
