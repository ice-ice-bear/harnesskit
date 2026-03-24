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

EXIT2=0
echo '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' | \
  (cd "$TMPDIR" && bash "$HOOKS/guardrails.sh") >/dev/null 2>&1 || EXIT2=$?
check "Safe command allowed" "[ $EXIT2 -eq 0 ]"

echo "=== Phase 3: Simulate work (write scratch file) ==="
echo '{"type":"error","pattern":"test error","file":"src/app.ts"}' > "$TMPDIR/.harnesskit/current-session.jsonl"
echo "feat-002" > "$TMPDIR/.harnesskit/current-feature.txt"

echo "=== Phase 4: Session End ==="
(cd "$TMPDIR" && bash "$HOOKS/session-end.sh" 2>/dev/null || true)
check "Session log exists" "ls '$TMPDIR/.harnesskit/session-logs/'*.json 2>/dev/null | head -1"
check "Scratch file cleaned" "[ ! -f '$TMPDIR/.harnesskit/current-session.jsonl' ]"
check "Failure recorded" "jq -e '.failures | length > 0' '$TMPDIR/.harnesskit/failures.json' >/dev/null 2>&1"

rm -rf "$TMPDIR"

echo "=== Phase 5: Post-edit-lint preset check ==="
TMPDIR5=$(mktemp -d)
mkdir -p "$TMPDIR5/.harnesskit"
cat > "$TMPDIR5/.harnesskit/config.json" <<'CONF'
{"preset": "advanced"}
CONF
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' > "$TMPDIR5/input.json"

EXIT5=0
export CLAUDE_PLUGIN_ROOT="$SCRIPT_DIR/.."
(cd "$TMPDIR5" && cat input.json | bash "$HOOKS/post-edit-lint.sh") >/dev/null 2>&1 || EXIT5=$?
check "post-edit-lint exits early on advanced preset" "[ $EXIT5 -eq 0 ]"
unset CLAUDE_PLUGIN_ROOT
rm -rf "$TMPDIR5"

echo "=== Phase 6: Post-edit-typecheck preset check ==="
TMPDIR6=$(mktemp -d)
mkdir -p "$TMPDIR6/.harnesskit"
cat > "$TMPDIR6/.harnesskit/config.json" <<'CONF'
{"preset": "advanced"}
CONF
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' > "$TMPDIR6/input.json"

EXIT6=0
export CLAUDE_PLUGIN_ROOT="$SCRIPT_DIR/.."
(cd "$TMPDIR6" && cat input.json | bash "$HOOKS/post-edit-typecheck.sh") >/dev/null 2>&1 || EXIT6=$?
check "post-edit-typecheck exits early on advanced preset" "[ $EXIT6 -eq 0 ]"
unset CLAUDE_PLUGIN_ROOT
rm -rf "$TMPDIR6"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
