#!/bin/bash
# post-edit-typecheck.sh — PostToolUse hook: typecheck on .ts/.tsx changes
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")

if [ "$TOOL" != "Edit" ] && [ "$TOOL" != "Write" ]; then
  exit 0
fi

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path' 2>/dev/null || echo "")

case "$FILE" in
  *.ts|*.tsx)
    npx tsc --noEmit 2>&1 | head -20 || true
    ;;
esac
