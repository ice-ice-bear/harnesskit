#!/bin/bash
# Regression tests for the FILES_CHANGED fallback in hooks/session-end.sh.
#
# Bug: under `set -o pipefail`, a failing `git diff` still lets `jq` print "[]" for empty
# input, and the old `|| echo "[]"` fallback then appended a SECOND "[]", producing
# "[]\n[]" which `jq --argjson` rejects ("invalid JSON text passed to --argjson").
# The hook aborted before writing the session log (leaving a 0-byte file).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/session-end.sh"
PASS=0
FAIL=0
NOTE="git diff unavailable"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
# Stop git from discovering a repository ABOVE the temp dir (e.g. if TMPDIR is inside a
# work tree), so the "unusable .git" and "missing .git" cases test what they claim to.
export GIT_CEILING_DIRECTORIES="$WORK"

check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label"
    FAIL=$((FAIL + 1))
  fi
}

# commit helper that does not depend on a global git identity
gcommit() { git -c user.name=test -c user.email=test@example.invalid commit -q "$@"; }

# run_case <name> <setup-function>: builds a fresh project dir, runs the real hook in it,
# leaves rc / stderr / session-log path in globals.
run_case() {
  local name="$1" setup="$2"
  CASE_DIR="$WORK/$name"
  mkdir -p "$CASE_DIR"
  (cd "$CASE_DIR" && "$setup")
  set +e
  (cd "$CASE_DIR" && bash "$HOOK" >"$CASE_DIR/stdout" 2>"$CASE_DIR/stderr")
  CASE_RC=$?
  set -e
  CASE_LOG=$(ls "$CASE_DIR/.harnesskit/session-logs/"*.json 2>/dev/null | head -1 || true)
}

log_is_valid()       { [ -n "${CASE_LOG:-}" ] && jq -e . "$CASE_LOG"; }
files_changed_is()   { jq -e --argjson want "$1" '.filesChanged == $want' "$CASE_LOG"; }
has_audit_fields()   { jq -e 'has("sessionId") and has("endedAt") and has("errors") and has("featuresCompleted") and has("rawToolSequence") and has("pluginUsage")' "$CASE_LOG"; }
stderr_has_note()    { grep -q "$NOTE" "$CASE_DIR/stderr"; }
stderr_lacks_note()  { ! grep -q "$NOTE" "$CASE_DIR/stderr"; }
hook_exited_zero()   { [ "$CASE_RC" -eq 0 ]; }
start_time_cleaned() { [ ! -f "$CASE_DIR/.harnesskit/session-start-time.txt" ]; }

base_setup() { mkdir -p .harnesskit/session-logs; echo "2026-01-01T00:00:00Z" > .harnesskit/session-start-time.txt; }

setup_normal()     { base_setup; git init -q; echo a > tracked.txt; git add .; gcommit -m init; echo b >> tracked.txt; }
setup_clean()      { base_setup; git init -q; echo a > tracked.txt; git add .; gcommit -m init; }
setup_unusable()   { base_setup; mkdir .git; echo "ref: refs/heads/main" > .git/HEAD; }
setup_missing()    { base_setup; }
setup_nocommits()  { base_setup; git init -q; }

echo "=== Session End: git fallback (FILES_CHANGED) ==="

echo "-- normal Git repository (tracked file modified)"
run_case normal setup_normal
check "hook exits 0"                     hook_exited_zero
check "session log is valid JSON"        log_is_valid
check "filesChanged lists the change"    files_changed_is '["tracked.txt"]'
check "no git warning on stderr"         stderr_lacks_note

echo "-- clean Git repository"
run_case clean setup_clean
check "hook exits 0"                     hook_exited_zero
check "session log is valid JSON"        log_is_valid
check "filesChanged is empty"            files_changed_is '[]'
check "no git warning on stderr"         stderr_lacks_note

echo "-- unusable Git directory (.git present, git cannot use it)"
run_case unusable setup_unusable
check "hook exits 0"                     hook_exited_zero
check "session log is valid JSON"        log_is_valid
check "filesChanged falls back to []"    files_changed_is '[]'
check "git warning on stderr"            stderr_has_note
check "audit fields preserved"           has_audit_fields
check "session-start-time cleaned up"    start_time_cleaned

echo "-- missing .git"
run_case missing setup_missing
check "hook exits 0"                     hook_exited_zero
check "session log is valid JSON"        log_is_valid
check "filesChanged is empty"            files_changed_is '[]'
check "no git warning on stderr"         stderr_lacks_note

echo "-- uninitialized repository (git init, no commits)"
run_case nocommits setup_nocommits
check "hook exits 0"                     hook_exited_zero
check "session log is valid JSON"        log_is_valid
check "filesChanged falls back to []"    files_changed_is '[]'
check "git warning on stderr"            stderr_has_note
check "audit fields preserved"           has_audit_fields
check "session-start-time cleaned up"    start_time_cleaned

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
