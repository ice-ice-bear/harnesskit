# Plan 1: Plugin Skeleton + Repo Detection + Preset System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the HarnessKit plugin skeleton with repo auto-detection and preset selection, so that `/harnesskit:setup` can detect a project's tech stack and let the user choose an experience preset.

**Architecture:** Claude Code Plugin structure with `plugin.json` manifest, a `setup.md` skill as the entry point, a `detect-repo.sh` shell script for zero-token repo scanning, and JSON preset files defining per-level configuration. The setup skill orchestrates: run detection → show results → prompt preset selection → save config.

**Tech Stack:** Shell (bash), JSON, Claude Code Plugin SDK (skills, agents)

**Spec:** `docs/superpowers/specs/2026-03-19-harnesskit-design.md` — Sections 2, 3

---

## File Structure

```
harnesskit/
├── plugin.json                          # Plugin manifest (skills + agents)
├── scripts/
│   └── detect-repo.sh                   # Repo detection script
├── templates/
│   └── presets/
│       ├── beginner.json                # Preset: strong guardrails
│       ├── intermediate.json            # Preset: balanced
│       └── advanced.json                # Preset: minimal intervention
├── skills/
│   └── setup.md                         # /harnesskit:setup entry point
├── agents/
│   └── orchestrator.md                  # Multi-step flow orchestration
└── tests/
    ├── test-detect-repo.sh              # Detection script tests
    └── fixtures/                        # Mock project structures
        ├── nextjs-project/
        │   ├── package.json
        │   ├── next.config.js
        │   └── tsconfig.json
        ├── fastapi-project/
        │   ├── requirements.txt
        │   └── pyproject.toml
        └── empty-project/
            └── .gitkeep
```

---

### Task 1: Plugin Manifest + Directory Structure

**Files:**
- Create: `harnesskit/plugin.json`
- Create: `harnesskit/README.md`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p harnesskit/{skills,agents,hooks,templates/presets,templates/claude-md,templates/claudeignore,templates/skills,templates/agents,templates/feature-list,scripts,tests/fixtures}
```

- [ ] **Step 2: Write plugin.json**

```json
{
  "name": "harnesskit",
  "version": "0.1.0",
  "description": "Adaptive harness for vibe coders — detect, configure, observe, improve",
  "skills": [
    "skills/setup.md"
  ],
  "agents": [
    "agents/orchestrator.md"
  ]
}
```

- [ ] **Step 3: Write minimal README.md**

```markdown
# HarnessKit

Adaptive harness for vibe coders — detect, configure, observe, improve.

## Install

\`\`\`bash
claude plugin install harnesskit
\`\`\`

## Quick Start

\`\`\`
/harnesskit:setup
\`\`\`
```

- [ ] **Step 4: Commit**

```bash
git add harnesskit/
git commit -m "feat: initialize plugin skeleton with manifest and directory structure"
```

---

### Task 2: Preset JSON Files

**Files:**
- Create: `harnesskit/templates/presets/beginner.json`
- Create: `harnesskit/templates/presets/intermediate.json`
- Create: `harnesskit/templates/presets/advanced.json`

- [ ] **Step 1: Write beginner.json**

```json
{
  "name": "beginner",
  "description": "Strong guardrails, detailed briefings, maximum error protection",
  "guardrails": {
    "sudo": "BLOCK",
    "rm_rf_dangerous": "BLOCK",
    "env_write": "BLOCK",
    "git_push_force": "BLOCK",
    "git_reset_hard": "BLOCK",
    "npm_publish": "BLOCK",
    "test_skip": "WARN"
  },
  "briefing": "detailed",
  "featureListGranularity": "small",
  "sessionEndReminder": "force",
  "insightsNudgeThreshold": 2,
  "claudeMdDetail": "full",
  "devHooks": {
    "postEditLint": true,
    "postEditTypecheck": true,
    "preCommitTest": true
  }
}
```

- [ ] **Step 2: Write intermediate.json**

```json
{
  "name": "intermediate",
  "description": "Balanced guardrails, concise briefings, moderate automation",
  "guardrails": {
    "sudo": "BLOCK",
    "rm_rf_dangerous": "BLOCK",
    "env_write": "BLOCK",
    "git_push_force": "BLOCK",
    "git_reset_hard": "WARN",
    "npm_publish": "WARN",
    "test_skip": "PASS"
  },
  "briefing": "summary",
  "featureListGranularity": "medium",
  "sessionEndReminder": "notify",
  "insightsNudgeThreshold": 3,
  "claudeMdDetail": "concise",
  "devHooks": {
    "postEditLint": true,
    "postEditTypecheck": true,
    "preCommitTest": false
  }
}
```

- [ ] **Step 3: Write advanced.json**

```json
{
  "name": "advanced",
  "description": "Minimal guardrails, one-line briefings, maximum autonomy",
  "guardrails": {
    "sudo": "BLOCK",
    "rm_rf_dangerous": "BLOCK",
    "env_write": "WARN",
    "git_push_force": "WARN",
    "git_reset_hard": "PASS",
    "npm_publish": "PASS",
    "test_skip": "PASS"
  },
  "briefing": "minimal",
  "featureListGranularity": "large",
  "sessionEndReminder": "silent",
  "insightsNudgeThreshold": 5,
  "claudeMdDetail": "minimal",
  "devHooks": {
    "postEditLint": false,
    "postEditTypecheck": false,
    "preCommitTest": false
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add harnesskit/templates/presets/
git commit -m "feat: add beginner/intermediate/advanced preset definitions"
```

---

### Task 3: Repo Detection Script

**Files:**
- Create: `harnesskit/scripts/detect-repo.sh`
- Create: `harnesskit/tests/test-detect-repo.sh`
- Create: `harnesskit/tests/fixtures/nextjs-project/package.json`
- Create: `harnesskit/tests/fixtures/nextjs-project/next.config.js`
- Create: `harnesskit/tests/fixtures/nextjs-project/tsconfig.json`
- Create: `harnesskit/tests/fixtures/fastapi-project/requirements.txt`
- Create: `harnesskit/tests/fixtures/empty-project/.gitkeep`

- [ ] **Step 1: Write test fixtures**

nextjs-project/package.json:
```json
{
  "name": "test-nextjs",
  "dependencies": {
    "next": "14.0.0",
    "react": "18.0.0"
  },
  "devDependencies": {
    "vitest": "1.0.0",
    "eslint": "8.0.0",
    "typescript": "5.0.0"
  }
}
```

nextjs-project/next.config.js:
```javascript
/** @type {import('next').NextConfig} */
module.exports = {}
```

nextjs-project/tsconfig.json:
```json
{ "compilerOptions": { "strict": true } }
```

fastapi-project/requirements.txt:
```
fastapi==0.100.0
uvicorn==0.23.0
pytest==7.4.0
ruff==0.1.0
```

- [ ] **Step 2: Write the test script**

```bash
#!/bin/bash
# test-detect-repo.sh — Tests for detect-repo.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT="$SCRIPT_DIR/../scripts/detect-repo.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

assert_json_field() {
  local json="$1" field="$2" expected="$3" label="$4"
  local actual
  actual=$(echo "$json" | jq -r ".$field")
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $label: $field = $actual"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label: $field expected '$expected' got '$actual'"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Test: Next.js project ==="
result=$(cd "$FIXTURES/nextjs-project" && bash "$DETECT")
assert_json_field "$result" "language" "typescript" "nextjs"
assert_json_field "$result" "framework" "nextjs" "nextjs"
assert_json_field "$result" "testFramework" "vitest" "nextjs"
assert_json_field "$result" "linter" "eslint" "nextjs"
assert_json_field "$result" "packageManager" "npm" "nextjs"

echo ""
echo "=== Test: FastAPI project ==="
result=$(cd "$FIXTURES/fastapi-project" && bash "$DETECT")
assert_json_field "$result" "language" "python" "fastapi"
assert_json_field "$result" "framework" "fastapi" "fastapi"
assert_json_field "$result" "testFramework" "pytest" "fastapi"
assert_json_field "$result" "linter" "ruff" "fastapi"

echo ""
echo "=== Test: Empty project ==="
result=$(cd "$FIXTURES/empty-project" && bash "$DETECT")
assert_json_field "$result" "language" "unknown" "empty"
assert_json_field "$result" "framework" "unknown" "empty"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 3: Run test to verify it fails**

```bash
chmod +x harnesskit/tests/test-detect-repo.sh
bash harnesskit/tests/test-detect-repo.sh
```

Expected: FAIL — `detect-repo.sh` does not exist yet.

- [ ] **Step 4: Write detect-repo.sh**

```bash
#!/bin/bash
# detect-repo.sh — Zero-token repo property detection
# Outputs JSON to stdout. No Claude API calls.
set -euo pipefail

PROJECT_DIR="${1:-.}"

# --- Language & Package Manager ---
language="unknown"
packageManager="unknown"

if [ -f "$PROJECT_DIR/package.json" ]; then
  language="javascript"
  if [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
    packageManager="pnpm"
  elif [ -f "$PROJECT_DIR/yarn.lock" ]; then
    packageManager="yarn"
  elif [ -f "$PROJECT_DIR/bun.lockb" ]; then
    packageManager="bun"
  else
    packageManager="npm"
  fi
  # Check for TypeScript
  if [ -f "$PROJECT_DIR/tsconfig.json" ] || \
     ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.typescript // .dependencies.typescript' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
    language="typescript"
  fi
elif [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ]; then
  language="python"
  if [ -f "$PROJECT_DIR/poetry.lock" ]; then
    packageManager="poetry"
  elif [ -f "$PROJECT_DIR/Pipfile.lock" ]; then
    packageManager="pipenv"
  elif [ -f "$PROJECT_DIR/uv.lock" ]; then
    packageManager="uv"
  else
    packageManager="pip"
  fi
elif [ -f "$PROJECT_DIR/go.mod" ]; then
  language="go"
  packageManager="go"
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
  language="rust"
  packageManager="cargo"
fi

# --- Framework ---
framework="unknown"

# JavaScript/TypeScript frameworks
if [ -f "$PROJECT_DIR/next.config.js" ] || [ -f "$PROJECT_DIR/next.config.mjs" ] || [ -f "$PROJECT_DIR/next.config.ts" ]; then
  framework="nextjs"
elif [ -f "$PROJECT_DIR/vite.config.js" ] || [ -f "$PROJECT_DIR/vite.config.ts" ] || [ -f "$PROJECT_DIR/vite.config.mjs" ]; then
  framework="vite"
elif [ -f "$PROJECT_DIR/nuxt.config.js" ] || [ -f "$PROJECT_DIR/nuxt.config.ts" ]; then
  framework="nuxt"
elif [ -f "$PROJECT_DIR/svelte.config.js" ]; then
  framework="sveltekit"
fi

# Python frameworks
if [ "$language" = "python" ]; then
  if [ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "fastapi" "$PROJECT_DIR/requirements.txt" 2>/dev/null; then
    framework="fastapi"
  elif [ -f "$PROJECT_DIR/pyproject.toml" ] && grep -qi "fastapi" "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    framework="fastapi"
  elif [ -f "$PROJECT_DIR/manage.py" ] || ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "django" "$PROJECT_DIR/requirements.txt" 2>/dev/null); then
    framework="django"
  elif [ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "flask" "$PROJECT_DIR/requirements.txt" 2>/dev/null; then
    framework="flask"
  fi
fi

# --- Test Framework ---
testFramework="unknown"

if [ -f "$PROJECT_DIR/vitest.config.js" ] || [ -f "$PROJECT_DIR/vitest.config.ts" ] || \
   ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.vitest' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
  testFramework="vitest"
elif [ -f "$PROJECT_DIR/jest.config.js" ] || [ -f "$PROJECT_DIR/jest.config.ts" ] || \
     ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.jest' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
  testFramework="jest"
elif [ "$language" = "python" ]; then
  if [ -f "$PROJECT_DIR/pytest.ini" ] || [ -f "$PROJECT_DIR/conftest.py" ] || \
     ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "pytest" "$PROJECT_DIR/requirements.txt" 2>/dev/null) || \
     ([ -f "$PROJECT_DIR/pyproject.toml" ] && grep -qi "pytest" "$PROJECT_DIR/pyproject.toml" 2>/dev/null); then
    testFramework="pytest"
  fi
elif [ "$language" = "go" ]; then
  testFramework="go-test"
elif [ "$language" = "rust" ]; then
  testFramework="cargo-test"
fi

# --- Linter ---
linter="unknown"

if [ -f "$PROJECT_DIR/.eslintrc.js" ] || [ -f "$PROJECT_DIR/.eslintrc.json" ] || [ -f "$PROJECT_DIR/.eslintrc.yml" ] || [ -f "$PROJECT_DIR/eslint.config.js" ] || [ -f "$PROJECT_DIR/eslint.config.mjs" ] || \
   ([ -f "$PROJECT_DIR/package.json" ] && jq -e '.devDependencies.eslint' "$PROJECT_DIR/package.json" >/dev/null 2>&1); then
  linter="eslint"
elif [ -f "$PROJECT_DIR/biome.json" ]; then
  linter="biome"
fi

if [ "$language" = "python" ]; then
  if [ -f "$PROJECT_DIR/ruff.toml" ] || ([ -f "$PROJECT_DIR/pyproject.toml" ] && grep -qi "\[tool.ruff\]" "$PROJECT_DIR/pyproject.toml" 2>/dev/null) || \
     ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "ruff" "$PROJECT_DIR/requirements.txt" 2>/dev/null); then
    linter="ruff"
  elif [ -f "$PROJECT_DIR/.flake8" ] || ([ -f "$PROJECT_DIR/requirements.txt" ] && grep -qi "flake8" "$PROJECT_DIR/requirements.txt" 2>/dev/null); then
    linter="flake8"
  fi
fi

# --- Monorepo ---
monorepo=false
if [ -f "$PROJECT_DIR/turbo.json" ] || [ -f "$PROJECT_DIR/nx.json" ] || [ -f "$PROJECT_DIR/lerna.json" ]; then
  monorepo=true
elif [ -f "$PROJECT_DIR/pnpm-workspace.yaml" ]; then
  monorepo=true
elif [ -d "$PROJECT_DIR/packages" ] && [ -d "$PROJECT_DIR/apps" ]; then
  monorepo=true
fi

# --- Git ---
gitInitialized=false
if [ -d "$PROJECT_DIR/.git" ]; then
  gitInitialized=true
fi

# --- Existing Harness ---
existingClaudeMd=false
existingFeatureList=false
existingProgress=false
existingHarnesskit=false

[ -f "$PROJECT_DIR/CLAUDE.md" ] && existingClaudeMd=true
[ -f "$PROJECT_DIR/docs/feature_list.json" ] && existingFeatureList=true
[ -f "$PROJECT_DIR/progress/claude-progress.txt" ] && existingProgress=true
[ -d "$PROJECT_DIR/.harnesskit" ] && existingHarnesskit=true

# --- Output ---
cat <<EOF
{
  "language": "$language",
  "framework": "$framework",
  "packageManager": "$packageManager",
  "testFramework": "$testFramework",
  "linter": "$linter",
  "monorepo": $monorepo,
  "git": $gitInitialized,
  "existingHarness": {
    "claudeMd": $existingClaudeMd,
    "featureList": $existingFeatureList,
    "progress": $existingProgress,
    "harnesskit": $existingHarnesskit
  }
}
EOF
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
chmod +x harnesskit/scripts/detect-repo.sh
bash harnesskit/tests/test-detect-repo.sh
```

Expected: All assertions PASS.

- [ ] **Step 6: Commit**

```bash
git add harnesskit/scripts/detect-repo.sh harnesskit/tests/
git commit -m "feat: add repo detection script with test suite"
```

---

### Task 4: Setup Skill

**Files:**
- Create: `harnesskit/skills/setup.md`

- [ ] **Step 1: Write setup.md skill**

```markdown
---
name: setup
description: Detect project tech stack, choose experience preset, and initialize HarnessKit harness + toolkit
user_invocable: true
---

# /harnesskit:setup

You are the HarnessKit setup assistant. Your job is to detect the project's tech stack, help the user choose an experience preset, and initialize the harness infrastructure and toolkit.

## Step 1: Detect Project

Run the detection script:

\`\`\`bash
bash "$(claude plugin path harnesskit)/scripts/detect-repo.sh" "$(pwd)"
\`\`\`

Parse the JSON output and present results to the user:

\`\`\`
🔍 Project Detection Results:
  Language:        {language}
  Framework:       {framework}
  Package Manager: {packageManager}
  Test Framework:  {testFramework}
  Linter:          {linter}
  Monorepo:        {monorepo}
  Git:             {git}
\`\`\`

If existing harness files are detected, present options:
- (1) Merge — keep existing files, only create missing ones
- (2) Overwrite — regenerate all (backup existing to .harnesskit/backup/)
- (3) Cancel

## Step 2: Choose Preset

Present preset options:

\`\`\`
Choose your experience level:

  (1) 🟢 Beginner — Strong guardrails, step-by-step guidance, maximum protection
  (2) 🟡 Intermediate — Balanced guardrails, concise guidance, moderate autonomy
  (3) 🔴 Advanced — Minimal guardrails, no guidance, maximum autonomy
\`\`\`

Wait for user selection.

## Step 3: Save Detection + Config

Create `.harnesskit/` directory and save:

1. `.harnesskit/detected.json` — the detection script output
2. `.harnesskit/config.json` — with structure:

\`\`\`json
{
  "schemaVersion": "1.0.0",
  "preset": "{selected_preset}",
  "detectedAt": "{ISO timestamp}",
  "installedPlugins": [],
  "overrides": {}
}
\`\`\`

## Step 4: Hand off to Init

After saving config, invoke the orchestrator agent to proceed with file generation (init.md — Plan 2) and toolkit setup.

If init.md is not yet available (Plan 2 not implemented), output:

\`\`\`
✅ Detection and preset saved.
   .harnesskit/detected.json
   .harnesskit/config.json

⏳ File generation will be available after /harnesskit:init is implemented.
\`\`\`
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/setup.md
git commit -m "feat: add /harnesskit:setup skill with detection and preset selection"
```

---

### Task 5: Orchestrator Agent

**Files:**
- Create: `harnesskit/agents/orchestrator.md`

- [ ] **Step 1: Write orchestrator.md**

```markdown
---
name: orchestrator
description: Orchestrates multi-step HarnessKit flows (setup, insights) by coordinating skills in sequence
---

# HarnessKit Orchestrator

You coordinate multi-step HarnessKit workflows. You are called by skills that need to chain multiple operations together.

## Setup Flow

When called from `/harnesskit:setup` after detection and preset selection:

1. Run init skill to generate harness infrastructure files
2. Run toolkit generation (skills, hooks, commands)
3. Present marketplace plugin recommendations
4. Present agent recommendations
5. Summarize what was created

## Insights Flow

When called from `/harnesskit:insights`:

1. Collect data files (.harnesskit/session-logs/, failures.json, config.json, etc.)
2. Run analysis
3. Generate report
4. Present improvement proposals as diffs
5. Wait for user to run /harnesskit:apply

## Rules

- Always read .harnesskit/config.json first to determine current preset
- Never modify files directly — always propose changes for user approval
- If a required file is missing, suggest running /harnesskit:setup
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/agents/orchestrator.md
git commit -m "feat: add orchestrator agent for multi-step flow coordination"
```

---

### Task 6: Integration Test — Full Setup Flow

**Files:**
- Create: `harnesskit/tests/test-setup-flow.sh`

- [ ] **Step 1: Write integration test**

```bash
#!/bin/bash
# test-setup-flow.sh — Verify setup flow produces expected outputs
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

check() {
  local label="$1" condition="$2"
  if eval "$condition"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Test: Detection produces valid JSON ==="
result=$(cd "$FIXTURES/nextjs-project" && bash "$SCRIPT_DIR/../scripts/detect-repo.sh")
check "Valid JSON" "echo '$result' | jq empty 2>/dev/null"
check "Has language field" "echo '$result' | jq -e '.language' >/dev/null"
check "Has framework field" "echo '$result' | jq -e '.framework' >/dev/null"
check "Has existingHarness object" "echo '$result' | jq -e '.existingHarness' >/dev/null"

echo ""
echo "=== Test: Preset files are valid JSON ==="
for preset in beginner intermediate advanced; do
  file="$SCRIPT_DIR/../templates/presets/$preset.json"
  check "$preset.json is valid JSON" "jq empty '$file' 2>/dev/null"
  check "$preset.json has guardrails" "jq -e '.guardrails' '$file' >/dev/null"
  check "$preset.json has name" "jq -e '.name' '$file' >/dev/null"
done

echo ""
echo "=== Test: Plugin manifest is valid ==="
manifest="$SCRIPT_DIR/../plugin.json"
check "plugin.json is valid JSON" "jq empty '$manifest' 2>/dev/null"
check "Has name field" "jq -e '.name' '$manifest' >/dev/null"
check "Has skills array" "jq -e '.skills | length > 0' '$manifest' >/dev/null"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run integration test**

```bash
chmod +x harnesskit/tests/test-setup-flow.sh
bash harnesskit/tests/test-setup-flow.sh
```

Expected: All assertions PASS.

- [ ] **Step 3: Commit**

```bash
git add harnesskit/tests/test-setup-flow.sh
git commit -m "test: add integration test for setup flow components"
```

---

### Task 7: Reset Mode in Setup Skill

**Files:**
- Modify: `harnesskit/skills/setup.md`

- [ ] **Step 1: Add reset mode to setup.md**

Append to the existing setup.md skill:

```markdown
## Reset Mode (/harnesskit:reset)

When invoked as `/harnesskit:reset`:

1. Show current preset from `.harnesskit/config.json`
2. Ask user to select new preset (or keep same)
3. **Preserved files** (never deleted):
   - `.harnesskit/failures.json`
   - `.harnesskit/session-logs/`
   - `.harnesskit/insights-history.json`
   - `docs/feature_list.json`
4. **Backed up then regenerated**:
   - `CLAUDE.md` → `.harnesskit/backup/CLAUDE.md.{timestamp}`
   - `.claudeignore` → `.harnesskit/backup/`
5. **Regenerated**:
   - `.harnesskit/config.json` (new preset)
   - `.harnesskit/detected.json` (re-run detection)
   - `CLAUDE.md` (new preset + re-detection)
   - `.claudeignore` (re-detection)
6. Re-run toolkit generation (skills, hooks, agents) with new preset

### --full flag

`/harnesskit:reset --full`:
1. Confirm with user: "This will delete all HarnessKit data. Continue? (y/n)"
2. Delete entire `.harnesskit/` directory
3. Remove harnesskit hooks from `.claude/settings.json`
4. Output: "HarnessKit fully removed. Run /harnesskit:setup to re-initialize."
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/setup.md
git commit -m "feat: add /harnesskit:reset mode to setup skill"
```

---

## Summary

After completing Plan 1, you have:
- ✅ `plugin.json` — valid Claude Code Plugin manifest
- ✅ `detect-repo.sh` — detects language, framework, test framework, linter, monorepo, git, existing harness
- ✅ 3 preset JSON files — beginner/intermediate/advanced with all configuration fields
- ✅ `setup.md` — skill that runs detection and prompts preset selection
- ✅ `orchestrator.md` — agent for coordinating multi-step flows
- ✅ Test suite — unit tests for detection + integration tests for all components

**Next:** Plan 2 — File Generation (Infrastructure + Toolkit)
