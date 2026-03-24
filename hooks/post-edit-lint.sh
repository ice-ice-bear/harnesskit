#!/bin/bash
# post-edit-lint.sh — PostToolUse hook: auto-lint changed files
# Only runs for Edit/Write tool calls on lintable files
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")

if [ "$TOOL" != "Edit" ] && [ "$TOOL" != "Write" ]; then
  exit 0
fi

# Preset check: respect devHooks.postEditLint setting
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# Intentionally // true: lint is enabled by default (opt-out)
ENABLED=$(jq -r '.devHooks.postEditLint // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0

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
