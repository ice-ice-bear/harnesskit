# Plan 3: Hooks System — Session Management + Guardrails

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the three core harness hooks (session-start, guardrails, session-end) that automate session management, enforce safety guardrails, and collect session data — all at zero token cost.

**Architecture:** Three shell scripts registered as Claude Code hooks. `session-start.sh` reads project state and outputs a briefing. `guardrails.sh` intercepts tool calls via stdin JSON and blocks dangerous operations. `session-end.sh` reads the scratch file (`current-session.jsonl`) written by Claude during the session, generates session logs, updates failures.json, and detects repeated patterns for nudges.

**Tech Stack:** Shell (bash), jq for JSON parsing

**Spec:** `docs/superpowers/specs/2026-03-19-harnesskit-design.md` — Sections 5, 7

**Depends on:** Plan 1 (config.json, detected.json), Plan 2 (.harnesskit/ structure)

---

## File Structure

**Note:** `compile-briefing.sh` and `scan-session-logs.sh` (listed in spec file tree) are intentionally inlined into `session-start.sh` and `session-end.sh` respectively. This keeps each hook self-contained and avoids cross-script dependencies. The spec file tree will be updated to reflect this simplification.

```
harnesskit/
├── hooks/
│   ├── session-start.sh                 # SessionStart: briefing injection (includes briefing composition)
│   ├── guardrails.sh                    # PreToolUse: dangerous action blocking
│   └── session-end.sh                   # Stop: log + failures + nudge (includes pattern scanning)
└── tests/
    ├── test-session-start.sh
    ├── test-guardrails.sh
    ├── test-session-end.sh
    └── fixtures/
        ├── mock-config-intermediate.json
        ├── mock-feature-list.json
        ├── mock-failures.json
        ├── mock-progress.txt
        ├── mock-current-session.jsonl
        └── mock-pretooluse-inputs/
            ├── bash-sudo.json
            ├── bash-rm-rf.json
            ├── bash-git-push-force.json
            ├── bash-safe.json
            ├── write-env.json
            ├── write-safe.json
            └── edit-test-skip.json
```

---

### Task 1: Test Fixtures

**Files:**
- Create: all fixture files under `harnesskit/tests/fixtures/`

- [ ] **Step 1: Create mock config and data files**

mock-config-intermediate.json:
```json
{
  "schemaVersion": "1.0.0",
  "preset": "intermediate",
  "detectedAt": "2026-03-19T10:00:00Z",
  "installedPlugins": [],
  "overrides": {}
}
```

mock-feature-list.json:
```json
{
  "version": "1.0.0",
  "features": [
    {"id": "feat-001", "description": "Login form", "passes": true},
    {"id": "feat-002", "description": "Signup API", "passes": false},
    {"id": "feat-003", "description": "Profile page", "passes": false}
  ]
}
```

mock-failures.json:
```json
{
  "failures": [
    {
      "id": "fail-001",
      "firstSeen": "2026-03-16",
      "lastSeen": "2026-03-18",
      "occurrences": 3,
      "feature": "feat-002",
      "pattern": "TypeError: Cannot read property 'id' of undefined",
      "files": ["src/api/signup.ts"],
      "rootCause": null,
      "prevention": null,
      "status": "open"
    }
  ]
}
```

mock-progress.txt:
```
# Session 3
## Completed
- feat-001: Login form implemented and tested
## Currently broken
- Nothing
## Next session
- feat-002: Signup API
## Notes
- Using Pydantic v2 schema validation
```

mock-current-session.jsonl:
```
{"type":"error","pattern":"TypeError: Cannot read property 'id' of undefined","file":"src/api/signup.ts"}
{"type":"error","pattern":"TypeError: Cannot read property 'id' of undefined","file":"src/api/signup.ts"}
{"type":"feature_fail","id":"feat-002"}
```

- [ ] **Step 2: Create PreToolUse input fixtures**

bash-sudo.json:
```json
{"tool_name": "Bash", "tool_input": {"command": "sudo apt-get install nginx"}}
```

bash-rm-rf.json:
```json
{"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}
```

bash-git-push-force.json:
```json
{"tool_name": "Bash", "tool_input": {"command": "git push --force origin main"}}
```

bash-safe.json:
```json
{"tool_name": "Bash", "tool_input": {"command": "npm test"}}
```

write-env.json:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/.env", "content": "SECRET=xxx"}}
```

write-safe.json:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/src/app.ts", "content": "console.log('hi')"}}
```

edit-test-skip.json:
```json
{"tool_name": "Edit", "tool_input": {"file_path": "/project/test.ts", "old_string": "it('should work'", "new_string": "it.skip('should work'"}}
```

- [ ] **Step 3: Commit**

```bash
git add harnesskit/tests/fixtures/
git commit -m "test: add fixtures for hooks testing"
```

---

### Task 2: Guardrails Hook

**Files:**
- Create: `harnesskit/hooks/guardrails.sh`
- Create: `harnesskit/tests/test-guardrails.sh`

- [ ] **Step 1: Write test-guardrails.sh**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/guardrails.sh"
INPUTS="$SCRIPT_DIR/fixtures/mock-pretooluse-inputs"
PASS=0
FAIL=0

# Create temp dir with mock config
TMPDIR=$(mktemp -d)
cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR/.harnesskit/config.json" 2>/dev/null || {
  mkdir -p "$TMPDIR/.harnesskit"
  cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR/.harnesskit/config.json"
}

assert_exit() {
  local input_file="$1" expected_exit="$2" label="$3"
  local actual_exit=0
  (cd "$TMPDIR" && cat "$input_file" | bash "$HOOK") >/dev/null 2>&1 || actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  ✅ $label (exit=$actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected exit=$expected_exit, got=$actual_exit)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Guardrails: intermediate preset ==="
# BLOCK cases (exit 2)
assert_exit "$INPUTS/bash-sudo.json" 2 "sudo → BLOCK"
assert_exit "$INPUTS/bash-rm-rf.json" 2 "rm -rf / → BLOCK"
assert_exit "$INPUTS/bash-git-push-force.json" 2 "git push --force → BLOCK"
assert_exit "$INPUTS/write-env.json" 2 ".env write → BLOCK"

# WARN cases (exit 0, but with stderr)
assert_exit "$INPUTS/edit-test-skip.json" 0 "it.skip → PASS (intermediate)"

# PASS cases (exit 0)
assert_exit "$INPUTS/bash-safe.json" 0 "npm test → PASS"
assert_exit "$INPUTS/write-safe.json" 0 "safe write → PASS"

rm -rf "$TMPDIR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x harnesskit/tests/test-guardrails.sh
bash harnesskit/tests/test-guardrails.sh
```

Expected: FAIL — guardrails.sh does not exist yet.

- [ ] **Step 3: Write guardrails.sh**

```bash
#!/bin/bash
# guardrails.sh — PreToolUse hook: block/warn dangerous operations
# Exit 2 = BLOCK (tool call rejected), Exit 0 = PASS/WARN
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")
[ -z "$TOOL" ] && exit 0

# Load preset
PRESET="intermediate"
if [ -f ".harnesskit/config.json" ]; then
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")
fi

# Load preset guardrail rules
PRESET_FILE=""
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$PLUGIN_DIR/templates/presets/$PRESET.json" ]; then
  PRESET_FILE="$PLUGIN_DIR/templates/presets/$PRESET.json"
fi

get_rule() {
  local key="$1" default="$2"
  if [ -n "$PRESET_FILE" ]; then
    jq -r ".guardrails.$key // \"$default\"" "$PRESET_FILE" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

block_msg() {
  echo "🚫 HarnessKit: $1" >&2
  exit 2
}

warn_msg() {
  echo "⚠️  HarnessKit: $1" >&2
}

apply_rule() {
  local rule="$1" message="$2"
  case "$rule" in
    BLOCK) block_msg "$message" ;;
    WARN)  warn_msg "$message" ;;
    PASS)  ;;
  esac
}

case "$TOOL" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

    # sudo
    if echo "$CMD" | grep -qE '^\s*sudo\s'; then
      apply_rule "$(get_rule sudo BLOCK)" "sudo commands are blocked"
    fi

    # rm -rf dangerous paths
    if echo "$CMD" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|(-[a-zA-Z]*f[a-zA-Z]*r))\s+(/|~|\$HOME)'; then
      apply_rule "$(get_rule rm_rf_dangerous BLOCK)" "Destructive rm -rf is blocked"
    fi

    # git push --force
    if echo "$CMD" | grep -qE 'git\s+push\s+.*--force'; then
      apply_rule "$(get_rule git_push_force BLOCK)" "git push --force is blocked"
    fi

    # git reset --hard
    if echo "$CMD" | grep -qE 'git\s+reset\s+--hard'; then
      apply_rule "$(get_rule git_reset_hard WARN)" "git reset --hard detected"
    fi

    # npm publish
    if echo "$CMD" | grep -qE 'npm\s+publish'; then
      apply_rule "$(get_rule npm_publish WARN)" "npm publish detected"
    fi
    ;;

  Write|Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

    # Protected files
    if echo "$FILE" | grep -qE '(\.env|\.env\.|secrets|credentials)'; then
      apply_rule "$(get_rule env_write BLOCK)" "Writing to protected file: $FILE"
    fi

    if echo "$FILE" | grep -qE '\.git/'; then
      apply_rule "BLOCK" "Writing to .git/ is always blocked"
    fi

    # test.skip detection (Edit only)
    if [ "$TOOL" = "Edit" ]; then
      NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")
      if echo "$NEW_STRING" | grep -qE '(it\.skip|test\.skip|describe\.skip|xit|xdescribe)'; then
        apply_rule "$(get_rule test_skip PASS)" "Skipping tests detected in edit"
      fi
    fi
    ;;
esac

exit 0
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash harnesskit/tests/test-guardrails.sh
```

Expected: All assertions PASS.

- [ ] **Step 5: Commit**

```bash
chmod +x harnesskit/hooks/guardrails.sh
git add harnesskit/hooks/guardrails.sh harnesskit/tests/test-guardrails.sh
git commit -m "feat: add guardrails hook with preset-aware blocking rules"
```

---

### Task 3: Session Start Hook

**Files:**
- Create: `harnesskit/hooks/session-start.sh`
- Create: `harnesskit/tests/test-session-start.sh`

- [ ] **Step 1: Write test-session-start.sh**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/session-start.sh"
PASS=0
FAIL=0

# Setup mock project
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.harnesskit" "$TMPDIR/docs" "$TMPDIR/progress"
cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR/.harnesskit/config.json"
cp "$SCRIPT_DIR/fixtures/mock-feature-list.json" "$TMPDIR/docs/feature_list.json"
cp "$SCRIPT_DIR/fixtures/mock-failures.json" "$TMPDIR/.harnesskit/failures.json"
cp "$SCRIPT_DIR/fixtures/mock-progress.txt" "$TMPDIR/progress/claude-progress.txt"

check() {
  local label="$1" pattern="$2" output="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — pattern '$pattern' not found"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Session Start: intermediate preset ==="
output=$(cd "$TMPDIR" && bash "$HOOK" 2>/dev/null || true)
check "Contains progress" "feat-001" "$output"
check "Contains feature count" "1/3" "$output"
check "Contains failure warning" "Cannot read property" "$output"
check "Records start time" "true" "[ -f '$TMPDIR/.harnesskit/session-start-time.txt' ] && echo true || echo false"

rm -rf "$TMPDIR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — session-start.sh does not exist.

- [ ] **Step 3: Write session-start.sh**

```bash
#!/bin/bash
# session-start.sh — SessionStart hook: compile and output session briefing
# Zero token cost — all file reads, no Claude calls
set -euo pipefail

# Record start time
date -u +"%Y-%m-%dT%H:%M:%SZ" > .harnesskit/session-start-time.txt 2>/dev/null || true

# Load preset
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

# Read progress
PROGRESS=""
[ -f "progress/claude-progress.txt" ] && \
  PROGRESS=$(cat progress/claude-progress.txt 2>/dev/null || echo "No previous progress")

# Read feature list
TOTAL=0
DONE=0
if [ -f "docs/feature_list.json" ]; then
  TOTAL=$(jq '.features | length' docs/feature_list.json 2>/dev/null || echo 0)
  DONE=$(jq '[.features[] | select(.passes == true)] | length' docs/feature_list.json 2>/dev/null || echo 0)
fi

# Read recent failures
FAILURES=""
if [ -f ".harnesskit/failures.json" ]; then
  FAILURES=$(jq -r '.failures[] | select(.status == "open") | "  - [\(.id)] \(.pattern) (\(.occurrences)x)"' .harnesskit/failures.json 2>/dev/null || echo "")
fi

# Git log
GITLOG=""
[ -d ".git" ] && GITLOG=$(git log --oneline -5 2>/dev/null || echo "")

# Output based on preset
case "$PRESET" in
  beginner)
    cat <<BRIEFING
═══ HarnessKit Session Briefing ═══

📋 Progress:
$PROGRESS

📊 Feature Status: $DONE/$TOTAL completed

⚠️  Active Failures:
${FAILURES:-  None}

🔧 Next Steps:
  1. Run existing tests to verify baseline
  2. Select next feature from feature_list.json
  3. Write feature ID to .harnesskit/current-feature.txt
  4. Implement and test

📝 Recent Commits:
$GITLOG

════════════════════════════════════
BRIEFING
    ;;
  intermediate)
    cat <<BRIEFING
═══ HarnessKit Session Briefing ═══
📋 Progress: $DONE/$TOTAL features done
${FAILURES:+⚠️  Failures:
$FAILURES}
📝 Recent: $(echo "$GITLOG" | head -3)
════════════════════════════════════
BRIEFING
    ;;
  advanced)
    echo "[HK] $DONE/$TOTAL done${FAILURES:+ | ⚠️ open failures}"
    ;;
esac
```

- [ ] **Step 4: Run tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
chmod +x harnesskit/hooks/session-start.sh
git add harnesskit/hooks/session-start.sh harnesskit/tests/test-session-start.sh
git commit -m "feat: add session-start hook with preset-aware briefing"
```

---

### Task 4: Session End Hook

**Files:**
- Create: `harnesskit/hooks/session-end.sh`
- Create: `harnesskit/tests/test-session-end.sh`

- [ ] **Step 1: Write test-session-end.sh**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/session-end.sh"
PASS=0
FAIL=0

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.harnesskit/session-logs" "$TMPDIR/docs"
cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR/.harnesskit/config.json"
cp "$SCRIPT_DIR/fixtures/mock-failures.json" "$TMPDIR/.harnesskit/failures.json"
cp "$SCRIPT_DIR/fixtures/mock-current-session.jsonl" "$TMPDIR/.harnesskit/current-session.jsonl"
echo "feat-002" > "$TMPDIR/.harnesskit/current-feature.txt"
echo "2026-03-19T14:30:00Z" > "$TMPDIR/.harnesskit/session-start-time.txt"
cd "$TMPDIR" && git init -q && touch test.txt && git add . && git commit -q -m "init"

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

echo "=== Session End ==="
(cd "$TMPDIR" && bash "$HOOK" 2>/dev/null || true)

check "Session log created" "ls '$TMPDIR/.harnesskit/session-logs/'*.json 2>/dev/null | head -1"
check "current-session.jsonl deleted" "[ ! -f '$TMPDIR/.harnesskit/current-session.jsonl' ]"
check "failures.json updated" "jq -e '.failures[0].occurrences' '$TMPDIR/.harnesskit/failures.json' >/dev/null"

# Check session log content
LOG=$(ls "$TMPDIR/.harnesskit/session-logs/"*.json 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
  check "Log has errors" "jq -e '.errors | length > 0' '$LOG' >/dev/null"
  check "Log has currentFeature" "jq -e '.currentFeature == \"feat-002\"' '$LOG' >/dev/null"
fi

rm -rf "$TMPDIR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Write session-end.sh**

```bash
#!/bin/bash
# session-end.sh — Stop hook: save session log, update failures, detect patterns
set -euo pipefail

# --- Collect data ---
SESSION_ID=$(date +"%Y-%m-%d-%H%M")
STARTED_AT=""
[ -f ".harnesskit/session-start-time.txt" ] && \
  STARTED_AT=$(cat .harnesskit/session-start-time.txt 2>/dev/null || echo "")
ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

CURRENT_FEATURE=""
[ -f ".harnesskit/current-feature.txt" ] && \
  CURRENT_FEATURE=$(cat .harnesskit/current-feature.txt 2>/dev/null || echo "")

FILES_CHANGED="[]"
if [ -d ".git" ]; then
  FILES_CHANGED=$(git diff --name-only HEAD 2>/dev/null | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")
fi

# --- Parse scratch file ---
ERRORS="[]"
FEATURES_COMPLETED="[]"
FEATURES_FAILED="[]"

if [ -f ".harnesskit/current-session.jsonl" ]; then
  ERRORS=$(grep '"type":"error"' .harnesskit/current-session.jsonl 2>/dev/null | \
    jq -s 'group_by(.pattern) | map({pattern: .[0].pattern, file: .[0].file, count: length})' 2>/dev/null || echo "[]")

  FEATURES_COMPLETED=$(grep '"type":"feature_done"' .harnesskit/current-session.jsonl 2>/dev/null | \
    jq -s 'map(.id)' 2>/dev/null || echo "[]")

  FEATURES_FAILED=$(grep '"type":"feature_fail"' .harnesskit/current-session.jsonl 2>/dev/null | \
    jq -s 'map(.id) | unique' 2>/dev/null || echo "[]")

  rm -f .harnesskit/current-session.jsonl
fi

# --- Write session log ---
mkdir -p .harnesskit/session-logs
cat > ".harnesskit/session-logs/$SESSION_ID.json" <<EOF
{
  "sessionId": "$SESSION_ID",
  "startedAt": "$STARTED_AT",
  "endedAt": "$ENDED_AT",
  "currentFeature": "$CURRENT_FEATURE",
  "filesChanged": $FILES_CHANGED,
  "featuresCompleted": $FEATURES_COMPLETED,
  "featuresFailed": $FEATURES_FAILED,
  "errors": $ERRORS
}
EOF

# --- Update failures.json ---
if [ -f ".harnesskit/failures.json" ] && [ "$ERRORS" != "[]" ]; then
  echo "$ERRORS" | jq -c '.[]' 2>/dev/null | while IFS= read -r err; do
    PATTERN=$(echo "$err" | jq -r '.pattern')
    FILE=$(echo "$err" | jq -r '.file')
    COUNT=$(echo "$err" | jq -r '.count')

    EXISTING=$(jq -r --arg p "$PATTERN" '.failures[] | select(.pattern == $p) | .id' .harnesskit/failures.json 2>/dev/null || echo "")

    if [ -n "$EXISTING" ]; then
      # Update existing
      jq --arg p "$PATTERN" --arg d "$(date +%Y-%m-%d)" --argjson c "$COUNT" \
        '(.failures[] | select(.pattern == $p)) |= (.occurrences += $c | .lastSeen = $d)' \
        .harnesskit/failures.json > .harnesskit/failures.json.tmp && \
        mv .harnesskit/failures.json.tmp .harnesskit/failures.json
    else
      # Add new failure
      FAIL_ID="fail-$(printf '%03d' $(( $(jq '.failures | length' .harnesskit/failures.json) + 1 )))"
      jq --arg id "$FAIL_ID" --arg p "$PATTERN" --arg f "$FILE" --arg feat "$CURRENT_FEATURE" --arg d "$(date +%Y-%m-%d)" --argjson c "$COUNT" \
        '.failures += [{"id": $id, "firstSeen": $d, "lastSeen": $d, "occurrences": $c, "feature": $feat, "pattern": $p, "files": [$f], "rootCause": null, "prevention": null, "status": "open"}]' \
        .harnesskit/failures.json > .harnesskit/failures.json.tmp && \
        mv .harnesskit/failures.json.tmp .harnesskit/failures.json
    fi
  done
fi

# --- Detect repeated patterns (nudge) ---
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

case "$PRESET" in
  beginner)     THRESHOLD=2 ;;
  intermediate) THRESHOLD=3 ;;
  advanced)     THRESHOLD=5 ;;
  *)            THRESHOLD=3 ;;
esac

if [ -f ".harnesskit/failures.json" ]; then
  REPEATED=$(jq -r --argjson t "$THRESHOLD" '.failures[] | select(.status == "open" and .occurrences >= $t) | .pattern' .harnesskit/failures.json 2>/dev/null || echo "")
  if [ -n "$REPEATED" ]; then
    echo ""
    echo "💡 Repeated error patterns detected:"
    echo "$REPEATED" | while IFS= read -r p; do
      echo "   - $p"
    done
    echo "   Run /harnesskit:insights for analysis"
  fi
fi

rm -f .harnesskit/session-start-time.txt
```

- [ ] **Step 4: Run tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
chmod +x harnesskit/hooks/session-end.sh
git add harnesskit/hooks/session-end.sh harnesskit/tests/test-session-end.sh
git commit -m "feat: add session-end hook with log saving, failure tracking, and nudge detection"
```

---

### Task 5: Hooks Integration Test

**Files:**
- Create: `harnesskit/tests/test-hooks-integration.sh`

- [ ] **Step 1: Write integration test — full session lifecycle**

```bash
#!/bin/bash
# Simulate: session-start → guardrails → session-end → verify state
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS="$SCRIPT_DIR/../hooks"
PASS=0
FAIL=0

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.harnesskit/session-logs" "$TMPDIR/docs" "$TMPDIR/progress"
cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR/.harnesskit/config.json"
cp "$SCRIPT_DIR/fixtures/mock-feature-list.json" "$TMPDIR/docs/feature_list.json"
echo '{"failures":[]}' > "$TMPDIR/.harnesskit/failures.json"
echo "Initial progress" > "$TMPDIR/progress/claude-progress.txt"
cd "$TMPDIR" && git init -q && touch f.txt && git add . && git commit -q -m "init"

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

echo "=== Phase 1: Session Start ==="
(cd "$TMPDIR" && bash "$HOOKS/session-start.sh" >/dev/null 2>&1 || true)
check "Start time recorded" "[ -f '$TMPDIR/.harnesskit/session-start-time.txt' ]"

echo "=== Phase 2: Guardrails ==="
EXIT=0
echo '{"tool_name":"Bash","tool_input":{"command":"sudo rm -rf /"}}' | \
  (cd "$TMPDIR" && bash "$HOOKS/guardrails.sh") >/dev/null 2>&1 || EXIT=$?
check "Dangerous command blocked" "[ $EXIT -eq 2 ]"

echo "=== Phase 3: Simulate work (write scratch file) ==="
echo '{"type":"error","pattern":"test error","file":"src/app.ts"}' > "$TMPDIR/.harnesskit/current-session.jsonl"
echo "feat-002" > "$TMPDIR/.harnesskit/current-feature.txt"

echo "=== Phase 4: Session End ==="
(cd "$TMPDIR" && bash "$HOOKS/session-end.sh" 2>/dev/null || true)
check "Session log exists" "ls '$TMPDIR/.harnesskit/session-logs/'*.json 2>/dev/null | head -1"
check "Scratch file cleaned" "[ ! -f '$TMPDIR/.harnesskit/current-session.jsonl' ]"
check "Failure recorded" "jq -e '.failures | length > 0' '$TMPDIR/.harnesskit/failures.json' >/dev/null"

rm -rf "$TMPDIR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run integration test**

Expected: All PASS.

- [ ] **Step 3: Commit**

```bash
chmod +x harnesskit/tests/test-hooks-integration.sh
git add harnesskit/tests/test-hooks-integration.sh
git commit -m "test: add hooks integration test — full session lifecycle"
```

---

## Summary

After completing Plan 3, you have:
- ✅ `guardrails.sh` — preset-aware dangerous action blocking (sudo, rm -rf, force push, .env, test.skip)
- ✅ `session-start.sh` — preset-aware briefing injection (detailed/summary/minimal)
- ✅ `session-end.sh` — session log generation, failures.json update, repeated pattern nudge
- ✅ Full test suite — unit tests per hook + integration test for full lifecycle
- ✅ All hooks are zero-token (shell only, no Claude calls)

**Next:** Plan 4 — Insights + Apply System
