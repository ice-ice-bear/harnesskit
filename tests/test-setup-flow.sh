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
manifest="$SCRIPT_DIR/../.claude-plugin/plugin.json"
check "plugin.json is valid JSON" "jq empty '$manifest' 2>/dev/null"
check "Has name field" "jq -e '.name' '$manifest' >/dev/null"
check "Has skills array" "jq -e '.skills | length > 0' '$manifest' >/dev/null"

echo ""
echo "=== Test: Skill and agent files exist ==="
check "setup.md exists" "[ -f '$SCRIPT_DIR/../skills/setup.md' ]"
check "orchestrator.md exists" "[ -f '$SCRIPT_DIR/../agents/orchestrator.md' ]"

echo ""
echo "=== Test: Scripts are executable ==="
check "detect-repo.sh is executable" "[ -x '$SCRIPT_DIR/../scripts/detect-repo.sh' ]"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
