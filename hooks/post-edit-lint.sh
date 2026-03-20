#!/bin/bash
# post-edit-lint.sh — PostToolUse hook: auto-lint changed files
# Only runs for Edit/Write tool calls on lintable files
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")

if [ "$TOOL" != "Edit" ] && [ "$TOOL" != "Write" ]; then
  exit 0
fi

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
