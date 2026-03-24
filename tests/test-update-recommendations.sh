#!/bin/bash
# test-update-recommendations.sh — Verify crawl script and output schema
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/update-recommendations.sh"
RECS="$SCRIPT_DIR/../templates/marketplace-recommendations.json"
PASS=0
FAIL=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected: $expected, got: $actual"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Script exists and is executable ==="
check "script exists" "$([ -f "$SCRIPT" ] && echo yes || echo no)" "yes"
check "script is executable" "$([ -x "$SCRIPT" ] && echo yes || echo no)" "yes"

echo ""
echo "=== Output file schema (existing) ==="
check "has schemaVersion" "$(jq -r '.schemaVersion' "$RECS" 2>/dev/null)" "1.0"
check "has recommendations array" "$(jq '.recommendations | type' "$RECS" 2>/dev/null)" '"array"'
check "has conditions object" "$(jq '.conditions | type' "$RECS" 2>/dev/null)" '"object"'
check "has lastUpdated" "$(jq -e '.lastUpdated' "$RECS" >/dev/null 2>&1 && echo yes || echo no)" "yes"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
