# Plan 2: File Generation — Infrastructure + Toolkit

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After Plan 1's detection + preset, generate all harness infrastructure files (CLAUDE.md, feature_list, progress, .claudeignore) and the toolkit (repo-specific skills, dev hooks, dev commands, marketplace/agent recommendations).

**Architecture:** Template-based generation using `init.md` skill. CLAUDE.md is composed from `base.md` + framework template + preset filter. Skills and agents come from marketplace (no seed templates — "Marketplace First, Customize Later"). Dev hooks and commands are registered in `.claude/settings.json`. Customization via `/skill-builder` happens later based on insights data.

**Tech Stack:** Shell (bash), Markdown templates, JSON, Claude Code Plugin SDK

**Spec:** `docs/superpowers/specs/2026-03-19-harnesskit-design.md` — Sections 4, 9

**Depends on:** Plan 1 (detection + preset saved to `.harnesskit/`)

---

## File Structure

```
harnesskit/
├── skills/
│   ├── init.md                          # File generation orchestration
│   ├── test.md                          # /harnesskit:test command
│   ├── lint.md                          # /harnesskit:lint command
│   ├── typecheck.md                     # /harnesskit:typecheck command
│   └── dev.md                           # /harnesskit:dev command
├── hooks/
│   ├── post-edit-lint.sh                # PostToolUse: auto lint
│   └── post-edit-typecheck.sh           # PostToolUse: auto typecheck
├── templates/
│   ├── claude-md/
│   │   ├── base.md                      # Common session protocol
│   │   ├── nextjs.md                    # Next.js conventions
│   │   ├── python-fastapi.md            # FastAPI conventions
│   │   ├── react-vite.md               # React + Vite conventions
│   │   ├── python-django.md             # Django conventions
│   │   └── generic.md                   # Fallback
│   ├── claudeignore/
│   │   ├── nextjs.txt
│   │   ├── python.txt
│   │   └── generic.txt
│   └── feature-list/
│       └── starter.json
└── tests/
    └── test-init-templates.sh           # Template validity tests
```

Generated in user project:
```
user-project/
├── CLAUDE.md
├── .claudeignore
├── .claude/settings.json                # hooks registered
├── docs/feature_list.json
├── progress/claude-progress.txt
└── .harnesskit/
    ├── config.json                      # (from Plan 1)
    ├── detected.json                    # (from Plan 1)
    ├── failures.json                    # empty initial
    ├── insights-history.json            # empty initial
    ├── skills/                          # initially empty — created by insights via /skill-builder
    │   └── (marketplace plugin customization or gap-filling)
    └── agents/                          # initially empty — marketplace agents recommended
        └── (v2: insights-based auto-generation)
```

---

### Task 1: CLAUDE.md Templates

**Files:**
- Create: `harnesskit/templates/claude-md/base.md`
- Create: `harnesskit/templates/claude-md/nextjs.md`
- Create: `harnesskit/templates/claude-md/python-fastapi.md`
- Create: `harnesskit/templates/claude-md/generic.md`

- [ ] **Step 1: Write base.md — common session protocol**

```markdown
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
```

- [ ] **Step 2: Write nextjs.md**

```markdown
## Next.js Conventions
- Server Components by default, `'use client'` only when needed
- App Router preferred over Pages Router
- Use `next/image` for all images
- API routes in `app/api/` with Route Handlers

## Skills Reference
- Next.js conventions → .harnesskit/skills/nextjs-conventions.md
- Testing patterns → .harnesskit/skills/nextjs-testing.md

## Test Command
- `{packageManager} test` or `{packageManager} run test`
```

- [ ] **Step 3: Write python-fastapi.md**

```markdown
## FastAPI Conventions
- Async endpoints by default
- Pydantic v2 for all schemas with `response_model`
- Standard response: `{"success": true, "data": {...}}`
- Error response: `{"success": false, "error": {"code": "...", "message": "..."}}`

## Skills Reference
- FastAPI conventions → .harnesskit/skills/fastapi-conventions.md
- Testing patterns → .harnesskit/skills/fastapi-testing.md

## Test Command
- `pytest -v`
```

- [ ] **Step 4: Write generic.md**

```markdown
## Conventions
- Follow existing project patterns
- Refer to project documentation for style guides

## Test Command
- Check project configuration for test scripts
```

- [ ] **Step 5: Commit**

```bash
git add harnesskit/templates/claude-md/
git commit -m "feat: add CLAUDE.md templates (base + nextjs + fastapi + generic)"
```

---

### Task 2: .claudeignore + feature_list Templates

**Files:**
- Create: `harnesskit/templates/claudeignore/nextjs.txt`
- Create: `harnesskit/templates/claudeignore/python.txt`
- Create: `harnesskit/templates/claudeignore/generic.txt`
- Create: `harnesskit/templates/feature-list/starter.json`

- [ ] **Step 1: Write claudeignore templates**

nextjs.txt:
```
.next/
node_modules/
dist/
coverage/
*.tsbuildinfo
.harnesskit/session-logs/
.harnesskit/backup/
```

python.txt:
```
__pycache__/
*.pyc
.venv/
venv/
.mypy_cache/
.pytest_cache/
htmlcov/
*.egg-info/
.harnesskit/session-logs/
.harnesskit/backup/
```

generic.txt:
```
.harnesskit/session-logs/
.harnesskit/backup/
```

- [ ] **Step 2: Write starter feature_list**

```json
{
  "version": "1.0.0",
  "features": []
}
```

- [ ] **Step 3: Commit**

```bash
git add harnesskit/templates/claudeignore/ harnesskit/templates/feature-list/
git commit -m "feat: add .claudeignore and feature_list starter templates"
```

---

### ~~Task 3: Skill Seed Templates~~ (REMOVED)

> **Removed**: Marketplace-first approach — no seed templates. Skills come from marketplace plugins. Customization via `/skill-builder` happens after insights data accumulation.

---

### ~~Task 4: Agent Templates~~ (REMOVED)

> **Removed**: Marketplace-first approach — no agent templates. Agents come from marketplace plugins. Custom agent generation is deferred to v2.

---

### Task 5: Dev Hooks

**Files:**
- Create: `harnesskit/hooks/post-edit-lint.sh`
- Create: `harnesskit/hooks/post-edit-typecheck.sh`

- [ ] **Step 1: Write post-edit-lint.sh**

```bash
#!/bin/bash
# post-edit-lint.sh — PostToolUse hook: auto-lint changed files
# Only runs for Edit/Write tool calls on lintable files
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")

if [ "$TOOL" != "Edit" ] && [ "$TOOL" != "Write" ]; then
  exit 0
fi

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path' 2>/dev/null || echo "")
[ -z "$FILE" ] && exit 0

# Determine linter from detected.json
DETECTED=".harnesskit/detected.json"
[ -f "$DETECTED" ] || exit 0
LINTER=$(jq -r '.linter' "$DETECTED" 2>/dev/null || echo "unknown")

case "$LINTER" in
  eslint)
    case "$FILE" in
      *.js|*.jsx|*.ts|*.tsx|*.mjs)
        npx eslint --fix "$FILE" 2>/dev/null || true
        ;;
    esac
    ;;
  ruff)
    case "$FILE" in
      *.py)
        ruff check --fix "$FILE" 2>/dev/null || true
        ruff format "$FILE" 2>/dev/null || true
        ;;
    esac
    ;;
  biome)
    case "$FILE" in
      *.js|*.jsx|*.ts|*.tsx)
        npx biome check --apply "$FILE" 2>/dev/null || true
        ;;
    esac
    ;;
esac
```

- [ ] **Step 2: Write post-edit-typecheck.sh**

```bash
#!/bin/bash
# post-edit-typecheck.sh — PostToolUse hook: typecheck on .ts/.tsx changes
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")

if [ "$TOOL" != "Edit" ] && [ "$TOOL" != "Write" ]; then
  exit 0
fi

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path' 2>/dev/null || echo "")

case "$FILE" in
  *.ts|*.tsx)
    npx tsc --noEmit 2>&1 | head -20 || true
    ;;
esac
```

- [ ] **Step 3: Write pre-commit-test.sh**

```bash
#!/bin/bash
# pre-commit-test.sh — PreToolUse hook: run tests before git commit
# Only activates for beginner preset
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")
[ "$TOOL" != "Bash" ] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
echo "$CMD" | grep -qE 'git\s+commit' || exit 0

# Check if enabled in preset
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENABLED=$(jq -r '.devHooks.preCommitTest // false' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "false")
[ "$ENABLED" != "true" ] && exit 0

# Detect test command
DETECTED=".harnesskit/detected.json"
[ -f "$DETECTED" ] || exit 0
TEST_FW=$(jq -r '.testFramework' "$DETECTED" 2>/dev/null || echo "unknown")

echo "🧪 HarnessKit: Running tests before commit..." >&2
case "$TEST_FW" in
  vitest)  npx vitest run --reporter=verbose 2>&1 | tail -5 ;;
  jest)    npx jest --verbose 2>&1 | tail -5 ;;
  pytest)  pytest -v 2>&1 | tail -5 ;;
  *)       echo "⚠️  Unknown test framework, skipping pre-commit test" >&2 ;;
esac
```

- [ ] **Step 4: Commit**

```bash
chmod +x harnesskit/hooks/post-edit-lint.sh harnesskit/hooks/post-edit-typecheck.sh harnesskit/hooks/pre-commit-test.sh
git add harnesskit/hooks/
git commit -m "feat: add dev hooks (auto-lint, auto-typecheck, pre-commit-test)"
```

---

### Task 6: Dev Command Skills

**Files:**
- Create: `harnesskit/skills/test.md`
- Create: `harnesskit/skills/lint.md`
- Create: `harnesskit/skills/typecheck.md`
- Create: `harnesskit/skills/dev.md`

- [ ] **Step 1: Write test.md**

```markdown
---
name: test
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
```

- [ ] **Step 2: Write lint.md, typecheck.md, dev.md** (similar structure, framework-aware)

- [ ] **Step 3: Update plugin.json with new skills**

```json
{
  "name": "harnesskit",
  "version": "0.1.0",
  "description": "Adaptive harness for vibe coders — detect, configure, observe, improve",
  "skills": [
    "skills/setup.md",
    "skills/init.md",
    "skills/test.md",
    "skills/lint.md",
    "skills/typecheck.md",
    "skills/dev.md"
  ],
  "agents": [
    "agents/orchestrator.md"
  ]
}
```

- [ ] **Step 4: Commit**

```bash
git add harnesskit/skills/ harnesskit/plugin.json
git commit -m "feat: add dev command skills (test, lint, typecheck, dev)"
```

---

### Task 7: Init Skill — Orchestrates All Generation

**Files:**
- Create: `harnesskit/skills/init.md`

- [ ] **Step 1: Write init.md**

```markdown
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

Preserve any existing hooks (append to arrays).

### 3. Marketplace Plugin Discovery ("Marketplace First, Customize Later")

Search marketplace for plugins matching detected project:

**Skills:**
1. Search for framework-specific skill plugins
2. Search for common skill plugins (code style, git workflow, etc.)
3. Recommend and install matching plugins — do NOT create custom skills at init time
4. Record gaps in `.harnesskit/config.json` for future insights

**Agents:**
1. Search for matching agent plugins (planner, reviewer, debugger, researcher)
2. Recommend and install matching plugins
3. For code review: prefer established marketplace plugins (e.g., `/review`)

**General recommendations** based on detected.json:
- All projects: `/simplify`
- Git remote detected: `/review`
- API project: `/security-review`

### 6. Summary

Output a summary of everything created:
```
✅ HarnessKit initialized!

📁 Files created:
  - CLAUDE.md (42 lines, Next.js + intermediate)
  - .claudeignore (12 patterns)
  - docs/feature_list.json (empty, ready to fill)
  - progress/claude-progress.txt (initialized)
  - .harnesskit/ (config, failures, insights-history)

🛠 Toolkit:
  - Skills: nextjs-conventions, nextjs-testing, typescript-standards
  - Dev Hooks: auto-lint (eslint), auto-typecheck (tsc)
  - Commands: /harnesskit:test, :lint, :typecheck, :dev
  - Agents: planner (installed)

📦 Recommended plugins:
  - /simplify — install with: claude plugin install simplify

🚀 Next: Add features to docs/feature_list.json and start coding!
```
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/init.md
git commit -m "feat: add init skill — orchestrates all harness + toolkit generation"
```

---

### Task 8: Template Validation Tests

**Files:**
- Create: `harnesskit/tests/test-init-templates.sh`

- [ ] **Step 1: Write template validation test**

```bash
#!/bin/bash
# test-init-templates.sh — Verify all templates exist and are valid
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES="$SCRIPT_DIR/../templates"
PASS=0
FAIL=0

check_file() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — NOT FOUND: $path"
    FAIL=$((FAIL + 1))
  fi
}

check_json() {
  local path="$1" label="$2"
  if [ -f "$path" ] && jq empty "$path" 2>/dev/null; then
    echo "  ✅ $label (valid JSON)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — invalid or missing"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== CLAUDE.md templates ==="
check_file "$TEMPLATES/claude-md/base.md" "base.md"
check_file "$TEMPLATES/claude-md/nextjs.md" "nextjs.md"
check_file "$TEMPLATES/claude-md/python-fastapi.md" "python-fastapi.md"
check_file "$TEMPLATES/claude-md/generic.md" "generic.md"

echo ""
echo "=== .claudeignore templates ==="
check_file "$TEMPLATES/claudeignore/nextjs.txt" "nextjs.txt"
check_file "$TEMPLATES/claudeignore/python.txt" "python.txt"
check_file "$TEMPLATES/claudeignore/generic.txt" "generic.txt"

echo ""
echo "=== Preset JSON ==="
check_json "$TEMPLATES/presets/beginner.json" "beginner.json"
check_json "$TEMPLATES/presets/intermediate.json" "intermediate.json"
check_json "$TEMPLATES/presets/advanced.json" "advanced.json"

echo ""
echo "=== Feature list starter ==="
check_json "$TEMPLATES/feature-list/starter.json" "starter.json"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run test**

```bash
chmod +x harnesskit/tests/test-init-templates.sh
bash harnesskit/tests/test-init-templates.sh
```

Expected: All template files exist and JSON is valid.

- [ ] **Step 3: Commit**

```bash
git add harnesskit/tests/test-init-templates.sh
git commit -m "test: add template validation tests for init"
```

---

## Summary

After completing Plan 2, you have:
- ✅ CLAUDE.md templates (base + 3 frameworks + generic) — composable
- ✅ .claudeignore templates per language
- ✅ ~~Skill seed templates~~ REMOVED — marketplace-first approach
- ✅ ~~Agent templates~~ REMOVED — marketplace-first approach
- ✅ Dev hooks (auto-lint, auto-typecheck)
- ✅ Dev commands (/harnesskit:test, :lint, :typecheck, :dev)
- ✅ `init.md` skill — orchestrates marketplace discovery + harness generation
- ✅ Template validation tests (updated: no skill/agent template assertions)

**Next:** Plan 3 — Hooks System (Session Management + Guardrails)
