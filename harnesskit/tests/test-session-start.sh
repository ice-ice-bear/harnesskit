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
  local label="$1" pattern="$2" source="$3"
  if echo "$source" | grep -q "$pattern"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — pattern '$pattern' not found"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Session Start: intermediate preset ==="
output=$(cd "$TMPDIR" && bash "$HOOK" 2>/dev/null || true)
check "Contains feature count" "1/3" "$output"
check "Contains failure warning" "Cannot read property" "$output"

# Check start time file was created
if [ -f "$TMPDIR/.harnesskit/session-start-time.txt" ]; then
  echo "  ✅ Start time recorded"
  PASS=$((PASS + 1))
else
  echo "  ❌ Start time not recorded"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
