#!/bin/bash
# guardrails.sh — PreToolUse hook: block/warn dangerous operations
# Exit 2 = BLOCK (tool call rejected), Exit 0 = PASS/WARN
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")
[ -z "$TOOL" ] && exit 0

# Load preset
PRESET="intermediate"
if [ -f ".harnesskit/config.json" ]; then
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")
fi

# Load preset guardrail rules
PRESET_FILE=""
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
if [ -f "$PLUGIN_DIR/templates/presets/$PRESET.json" ]; then
  PRESET_FILE="$PLUGIN_DIR/templates/presets/$PRESET.json"
fi

get_rule() {
  local key="$1" default="$2"
  if [ -n "$PRESET_FILE" ]; then
    jq -r ".guardrails.$key // \"$default\"" "$PRESET_FILE" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

block_msg() {
  echo "🚫 HarnessKit: $1" >&2
  exit 2
}

warn_msg() {
  echo "⚠️  HarnessKit: $1" >&2
}

apply_rule() {
  local rule="$1" message="$2"
  case "$rule" in
    BLOCK) block_msg "$message" ;;
    WARN)  warn_msg "$message" ;;
    PASS)  ;;
  esac
}

case "$TOOL" in
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

    # sudo
    if echo "$CMD" | grep -qE '^\s*sudo\s'; then
      apply_rule "$(get_rule sudo BLOCK)" "sudo commands are blocked"
    fi

    # rm -rf dangerous paths
    if echo "$CMD" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\s+(/|~|\$HOME)'; then
      apply_rule "$(get_rule rm_rf_dangerous BLOCK)" "Destructive rm -rf is blocked"
    fi

    # git push --force
    if echo "$CMD" | grep -qE 'git\s+push\s+.*--force'; then
      apply_rule "$(get_rule git_push_force BLOCK)" "git push --force is blocked"
    fi

    # git reset --hard
    if echo "$CMD" | grep -qE 'git\s+reset\s+--hard'; then
      apply_rule "$(get_rule git_reset_hard WARN)" "git reset --hard detected"
    fi

    # npm publish
    if echo "$CMD" | grep -qE 'npm\s+publish'; then
      apply_rule "$(get_rule npm_publish WARN)" "npm publish detected"
    fi
    ;;

  Write|Edit)
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

    # Protected files
    if echo "$FILE" | grep -qE '(\.env|\.env\.|secrets|credentials)'; then
      apply_rule "$(get_rule env_write BLOCK)" "Writing to protected file: $FILE"
    fi

    if echo "$FILE" | grep -qE '\.git/'; then
      apply_rule "BLOCK" "Writing to .git/ is always blocked"
    fi

    # test.skip detection (Edit only)
    if [ "$TOOL" = "Edit" ]; then
      NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")
      if echo "$NEW_STRING" | grep -qE '(it\.skip|test\.skip|describe\.skip|xit|xdescribe)'; then
        apply_rule "$(get_rule test_skip PASS)" "Skipping tests detected in edit"
      fi
    fi
    ;;
esac

exit 0
