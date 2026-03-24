#!/bin/bash
# post-edit-typecheck.sh — PostToolUse hook: typecheck on .ts/.tsx changes
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")

if [ "$TOOL" != "Edit" ] && [ "$TOOL" != "Write" ]; then
  exit 0
fi

# Preset check: respect devHooks.postEditTypecheck setting
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# Intentionally // true: typecheck is enabled by default (opt-out)
ENABLED=$(jq -r '.devHooks.postEditTypecheck // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path' 2>/dev/null || echo "")

case "$FILE" in
  *.ts|*.tsx)
    npx tsc --noEmit 2>&1 | head -20 || true
    ;;
esac
