#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/session-end.sh"
PASS=0
FAIL=0

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.harnesskit/session-logs" "$TMPDIR/docs"
cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR/.harnesskit/config.json"
echo '{"failures":[]}' > "$TMPDIR/.harnesskit/failures.json"
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
check "failures.json updated" "jq -e '.failures | length > 0' '$TMPDIR/.harnesskit/failures.json' >/dev/null 2>&1"

# Check session log content
LOG=$(ls "$TMPDIR/.harnesskit/session-logs/"*.json 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
  check "Log has errors" "jq -e '.errors | length > 0' '$LOG' >/dev/null 2>&1"
  check "Log has currentFeature" "jq -e '.currentFeature == \"feat-002\"' '$LOG' >/dev/null 2>&1"
fi

rm -rf "$TMPDIR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
