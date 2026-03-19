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
