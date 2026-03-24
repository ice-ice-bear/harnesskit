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

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
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
