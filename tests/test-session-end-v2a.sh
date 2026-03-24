#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/session-end.sh"
PASS=0
FAIL=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — expected: $expected, got: $actual"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# Group 1: Tool call sequence detection
# ============================================================
echo "=== Group 1: Tool call sequence detection ==="

TMPDIR1=$(mktemp -d)
mkdir -p "$TMPDIR1/.harnesskit/session-logs"
cp "$SCRIPT_DIR/fixtures/mock-config-v2a.json" "$TMPDIR1/.harnesskit/config.json"
echo '{"failures":[]}' > "$TMPDIR1/.harnesskit/failures.json"
cp "$SCRIPT_DIR/fixtures/mock-session-v2a.jsonl" "$TMPDIR1/.harnesskit/current-session.jsonl"
echo "feat-003" > "$TMPDIR1/.harnesskit/current-feature.txt"
echo "2026-03-20T14:30:00Z" > "$TMPDIR1/.harnesskit/session-start-time.txt"
(cd "$TMPDIR1" && git init -q && touch test.txt && git add . && git commit -q -m "init")

(cd "$TMPDIR1" && bash "$HOOK" 2>/dev/null || true)

LOG1=$(ls "$TMPDIR1/.harnesskit/session-logs/"*.json 2>/dev/null | head -1)

# 3-step tool:summary sequences
SEQ_COUNT=$(jq '.toolCallSequences | length' "$LOG1" 2>/dev/null || echo "0")
SEQ_HAS_ENTRIES=$([ "$SEQ_COUNT" -gt 0 ] && echo "true" || echo "false")
check "toolCallSequences has entries" "$SEQ_HAS_ENTRIES" "true"

# Check for the repeated pattern: Bash:tsc --noEmit → Edit:fix type in auth.ts → Bash:tsc --noEmit
TSC_CYCLE=$(jq '[.toolCallSequences[] | select(.sequence[0] == "Bash:tsc --noEmit" and .sequence[1] == "Edit:fix type in auth.ts" and .sequence[2] == "Bash:tsc --noEmit")] | .[0].count' "$LOG1" 2>/dev/null || echo "null")
check "tsc→edit→tsc cycle count >= 2" "$([ "$TSC_CYCLE" != "null" ] && [ "$TSC_CYCLE" -ge 2 ] && echo true || echo false)" "true"

# rawToolSequence exists and is an array of tool:summary strings
RAW_SEQ_LEN=$(jq '.rawToolSequence | length' "$LOG1" 2>/dev/null || echo "0")
RAW_SEQ_FORMAT=$(jq '.rawToolSequence[0] | test(":")' "$LOG1" 2>/dev/null || echo "false")
check "rawToolSequence has entries" "$([ "$RAW_SEQ_LEN" -gt 0 ] && echo true || echo false)" "true"
check "rawToolSequence uses tool:summary format" "$RAW_SEQ_FORMAT" "true"

rm -rf "$TMPDIR1"

# ============================================================
# Group 2: Task time distribution
# ============================================================
echo ""
echo "=== Group 2: Task time distribution ==="

TMPDIR2=$(mktemp -d)
mkdir -p "$TMPDIR2/.harnesskit/session-logs"
cp "$SCRIPT_DIR/fixtures/mock-config-v2a.json" "$TMPDIR2/.harnesskit/config.json"
echo '{"failures":[]}' > "$TMPDIR2/.harnesskit/failures.json"
cp "$SCRIPT_DIR/fixtures/mock-session-v2a.jsonl" "$TMPDIR2/.harnesskit/current-session.jsonl"
echo "feat-003" > "$TMPDIR2/.harnesskit/current-feature.txt"
echo "2026-03-20T14:30:00Z" > "$TMPDIR2/.harnesskit/session-start-time.txt"
(cd "$TMPDIR2" && git init -q && touch test.txt && git add . && git commit -q -m "init")

(cd "$TMPDIR2" && bash "$HOOK" 2>/dev/null || true)

LOG2=$(ls "$TMPDIR2/.harnesskit/session-logs/"*.json 2>/dev/null | head -1)

# coding = Bash:tsc(5) + Edit(3) + Write(1) = 9/12 = 0.75
CODING=$(jq '.taskTimeDistribution.coding' "$LOG2" 2>/dev/null || echo "null")
CODING_OK=$(jq -rn --argjson v "$CODING" 'if $v > 0.74 and $v < 0.76 then "true" else "false" end' 2>/dev/null || echo "false")
check "coding ratio ~0.75" "$CODING_OK" "true"

# debugging = Bash:npm test(1) = 1/12 ≈ 0.083
DEBUGGING=$(jq '.taskTimeDistribution.debugging' "$LOG2" 2>/dev/null || echo "null")
DEBUGGING_OK=$(jq -rn --argjson v "$DEBUGGING" 'if $v > 0.08 and $v < 0.09 then "true" else "false" end' 2>/dev/null || echo "false")
check "debugging ratio ~0.083" "$DEBUGGING_OK" "true"

# research = WebSearch(2) = 2/12 ≈ 0.167
RESEARCH=$(jq '.taskTimeDistribution.research' "$LOG2" 2>/dev/null || echo "null")
RESEARCH_OK=$(jq -rn --argjson v "$RESEARCH" 'if $v > 0.16 and $v < 0.17 then "true" else "false" end' 2>/dev/null || echo "false")
check "research ratio ~0.167" "$RESEARCH_OK" "true"

# ratios sum to 1
SUM_OK=$(jq -rn --argjson c "$CODING" --argjson d "$DEBUGGING" --argjson r "$RESEARCH" 'if ($c + $d + $r) > 0.999 and ($c + $d + $r) < 1.001 then "true" else "false" end' 2>/dev/null || echo "false")
check "ratios sum to 1" "$SUM_OK" "true"

rm -rf "$TMPDIR2"

# ============================================================
# Group 3: Plugin usage extraction
# ============================================================
echo ""
echo "=== Group 3: Plugin usage extraction ==="

TMPDIR3=$(mktemp -d)
mkdir -p "$TMPDIR3/.harnesskit/session-logs"
cp "$SCRIPT_DIR/fixtures/mock-config-v2a.json" "$TMPDIR3/.harnesskit/config.json"
echo '{"failures":[]}' > "$TMPDIR3/.harnesskit/failures.json"
cp "$SCRIPT_DIR/fixtures/mock-session-v2a.jsonl" "$TMPDIR3/.harnesskit/current-session.jsonl"
echo "feat-003" > "$TMPDIR3/.harnesskit/current-feature.txt"
echo "2026-03-20T14:30:00Z" > "$TMPDIR3/.harnesskit/session-start-time.txt"
(cd "$TMPDIR3" && git init -q && touch test.txt && git add . && git commit -q -m "init")

(cd "$TMPDIR3" && bash "$HOOK" 2>/dev/null || true)

LOG3=$(ls "$TMPDIR3/.harnesskit/session-logs/"*.json 2>/dev/null | head -1)

REVIEW_INVOCATIONS=$(jq '.pluginUsage.review.invocations' "$LOG3" 2>/dev/null || echo "null")
check "review plugin invocations" "$REVIEW_INVOCATIONS" "1"

SIMPLIFY_INVOCATIONS=$(jq '.pluginUsage.simplify.invocations' "$LOG3" 2>/dev/null || echo "null")
check "simplify plugin invocations" "$SIMPLIFY_INVOCATIONS" "1"

REVIEW_THEMES=$(jq '.pluginUsage.review.feedbackThemes | length' "$LOG3" 2>/dev/null || echo "null")
check "review feedbackThemes count" "$REVIEW_THEMES" "2"

SIMPLIFY_THEMES=$(jq '.pluginUsage.simplify.feedbackThemes | length' "$LOG3" 2>/dev/null || echo "null")
check "simplify feedbackThemes empty" "$SIMPLIFY_THEMES" "0"

rm -rf "$TMPDIR3"

# ============================================================
# Group 4: Backward compatibility (v1-only JSONL)
# ============================================================
echo ""
echo "=== Group 4: Backward compatibility ==="

TMPDIR4=$(mktemp -d)
mkdir -p "$TMPDIR4/.harnesskit/session-logs"
cp "$SCRIPT_DIR/fixtures/mock-config-v2a.json" "$TMPDIR4/.harnesskit/config.json"
echo '{"failures":[]}' > "$TMPDIR4/.harnesskit/failures.json"
cp "$SCRIPT_DIR/fixtures/mock-session-v2a-empty.jsonl" "$TMPDIR4/.harnesskit/current-session.jsonl"
echo "feat-002" > "$TMPDIR4/.harnesskit/current-feature.txt"
echo "2026-03-20T14:00:00Z" > "$TMPDIR4/.harnesskit/session-start-time.txt"
(cd "$TMPDIR4" && git init -q && touch test.txt && git add . && git commit -q -m "init")

(cd "$TMPDIR4" && bash "$HOOK" 2>/dev/null || true)

LOG4=$(ls "$TMPDIR4/.harnesskit/session-logs/"*.json 2>/dev/null | head -1)

# v1 fields still work
V1_ERRORS=$(jq '.errors | length' "$LOG4" 2>/dev/null || echo "null")
check "v1 errors still captured" "$V1_ERRORS" "1"

V1_FAILED=$(jq '.featuresFailed | length' "$LOG4" 2>/dev/null || echo "null")
check "v1 featuresFailed still captured" "$V1_FAILED" "1"

# v2a fields are empty
V2A_SEQS=$(jq '.toolCallSequences | length' "$LOG4" 2>/dev/null || echo "null")
check "toolCallSequences empty for v1-only" "$V2A_SEQS" "0"

V2A_DIST=$(jq '.taskTimeDistribution | keys | length' "$LOG4" 2>/dev/null || echo "null")
check "taskTimeDistribution empty for v1-only" "$V2A_DIST" "0"

V2A_PLUGINS=$(jq '.pluginUsage | keys | length' "$LOG4" 2>/dev/null || echo "null")
check "pluginUsage empty for v1-only" "$V2A_PLUGINS" "0"

rm -rf "$TMPDIR4"

# ============================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
