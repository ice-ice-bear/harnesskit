#!/bin/bash
# post-edit-lint.sh — PostToolUse hook: auto-lint changed files
# Only runs for Edit/Write tool calls on lintable files
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

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

# Determine linter and workspace roots from detected.json
DETECTED=".harnesskit/detected.json"
[ -f "$DETECTED" ] || exit 0
LINTER=$(jq -r '.linter' "$DETECTED" 2>/dev/null || echo "unknown")
JS_WS=$(jq -r '.workspaces.js // "."' "$DETECTED" 2>/dev/null || echo ".")
PY_WS=$(jq -r '.workspaces.python // "."' "$DETECTED" 2>/dev/null || echo ".")

case "$LINTER" in
  eslint*)
    case "$FILE" in
      *.js|*.jsx|*.ts|*.tsx|*.mjs)
        (cd "$JS_WS" 2>/dev/null && npx --no-install eslint --fix "$FILE") 2>/dev/null || true
        ;;
    esac
    ;;
  biome*)
    case "$FILE" in
      *.js|*.jsx|*.ts|*.tsx)
        (cd "$JS_WS" 2>/dev/null && npx --no-install biome check --apply "$FILE") 2>/dev/null || true
        ;;
    esac
    ;;
esac

# Run Python linter too (monorepos may have both)
case "$LINTER" in
  *ruff*)
    case "$FILE" in
      *.py)
        (cd "$PY_WS" 2>/dev/null && ruff check --fix "$FILE" && ruff format "$FILE") 2>/dev/null || true
        ;;
    esac
    ;;
esac
