#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/guardrails.sh"
INPUTS="$SCRIPT_DIR/fixtures/mock-pretooluse-inputs"
PASS=0
FAIL=0

assert_exit() {
  local input_file="$1" expected_exit="$2" label="$3"
  local actual_exit=0
  # Create temp dir with mock config
  local TMPDIR
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/.harnesskit"
  cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR/.harnesskit/config.json"

  (cd "$TMPDIR" && cat "$input_file" | bash "$HOOK") >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  ✅ $label (exit=$actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label (expected exit=$expected_exit, got=$actual_exit)"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$TMPDIR"
}

echo "=== Guardrails: intermediate preset ==="
# BLOCK cases (exit 2)
assert_exit "$INPUTS/bash-sudo.json" 2 "sudo → BLOCK"
assert_exit "$INPUTS/bash-rm-rf.json" 2 "rm -rf / → BLOCK"
assert_exit "$INPUTS/bash-git-push-force.json" 2 "git push --force → BLOCK"
assert_exit "$INPUTS/write-env.json" 2 ".env write → BLOCK"

# PASS cases (exit 0) — intermediate preset
assert_exit "$INPUTS/edit-test-skip.json" 0 "it.skip → PASS (intermediate)"
assert_exit "$INPUTS/bash-safe.json" 0 "npm test → PASS"
assert_exit "$INPUTS/write-safe.json" 0 "safe write → PASS"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
