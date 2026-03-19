#!/bin/bash
# session-end.sh — Stop hook: save session log, update failures, detect patterns
set -euo pipefail

# --- Collect data ---
SESSION_ID=$(date +"%Y-%m-%d-%H%M")
STARTED_AT=""
[ -f ".harnesskit/session-start-time.txt" ] && \
  STARTED_AT=$(cat .harnesskit/session-start-time.txt 2>/dev/null || echo "")
ENDED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

CURRENT_FEATURE=""
[ -f ".harnesskit/current-feature.txt" ] && \
  CURRENT_FEATURE=$(cat .harnesskit/current-feature.txt 2>/dev/null || echo "")

FILES_CHANGED="[]"
if [ -d ".git" ]; then
  FILES_CHANGED=$(git diff --name-only HEAD 2>/dev/null | jq -R -s 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "[]")
fi

# --- Parse scratch file ---
ERRORS="[]"
FEATURES_COMPLETED="[]"
FEATURES_FAILED="[]"

if [ -f ".harnesskit/current-session.jsonl" ]; then
  ERROR_LINES=$(grep '"type":"error"' .harnesskit/current-session.jsonl 2>/dev/null || true)
  if [ -n "$ERROR_LINES" ]; then
    ERRORS=$(echo "$ERROR_LINES" | jq -s 'group_by(.pattern) | map({pattern: .[0].pattern, file: .[0].file, count: length})' 2>/dev/null || echo "[]")
  fi

  DONE_LINES=$(grep '"type":"feature_done"' .harnesskit/current-session.jsonl 2>/dev/null || true)
  if [ -n "$DONE_LINES" ]; then
    FEATURES_COMPLETED=$(echo "$DONE_LINES" | jq -s 'map(.id)' 2>/dev/null || echo "[]")
  fi

  FAIL_LINES=$(grep '"type":"feature_fail"' .harnesskit/current-session.jsonl 2>/dev/null || true)
  if [ -n "$FAIL_LINES" ]; then
    FEATURES_FAILED=$(echo "$FAIL_LINES" | jq -s 'map(.id) | unique' 2>/dev/null || echo "[]")
  fi

  rm -f .harnesskit/current-session.jsonl
fi

# --- Write session log ---
mkdir -p .harnesskit/session-logs
jq -n \
  --arg sid "$SESSION_ID" \
  --arg start "$STARTED_AT" \
  --arg end "$ENDED_AT" \
  --arg feat "$CURRENT_FEATURE" \
  --argjson files "$FILES_CHANGED" \
  --argjson done "$FEATURES_COMPLETED" \
  --argjson failed "$FEATURES_FAILED" \
  --argjson errs "$ERRORS" \
  '{
    sessionId: $sid,
    startedAt: $start,
    endedAt: $end,
    currentFeature: $feat,
    filesChanged: $files,
    featuresCompleted: $done,
    featuresFailed: $failed,
    errors: $errs
  }' > ".harnesskit/session-logs/$SESSION_ID.json"

# --- Update failures.json ---
if [ -f ".harnesskit/failures.json" ] && [ "$ERRORS" != "[]" ]; then
  echo "$ERRORS" | jq -c '.[]' 2>/dev/null | while IFS= read -r err; do
    PATTERN=$(echo "$err" | jq -r '.pattern')
    FILE=$(echo "$err" | jq -r '.file')
    COUNT=$(echo "$err" | jq -r '.count')

    EXISTING=$(jq -r --arg p "$PATTERN" '.failures[] | select(.pattern == $p) | .id' .harnesskit/failures.json 2>/dev/null || echo "")

    if [ -n "$EXISTING" ]; then
      jq --arg p "$PATTERN" --arg d "$(date +%Y-%m-%d)" --argjson c "$COUNT" \
        '(.failures[] | select(.pattern == $p)) |= (.occurrences += $c | .lastSeen = $d)' \
        .harnesskit/failures.json > .harnesskit/failures.json.tmp && \
        mv .harnesskit/failures.json.tmp .harnesskit/failures.json
    else
      FAIL_ID="fail-$(printf '%03d' $(( $(jq '.failures | length' .harnesskit/failures.json) + 1 )))"
      jq --arg id "$FAIL_ID" --arg p "$PATTERN" --arg f "$FILE" --arg feat "$CURRENT_FEATURE" --arg d "$(date +%Y-%m-%d)" --argjson c "$COUNT" \
        '.failures += [{"id": $id, "firstSeen": $d, "lastSeen": $d, "occurrences": $c, "feature": $feat, "pattern": $p, "files": [$f], "rootCause": null, "prevention": null, "status": "open"}]' \
        .harnesskit/failures.json > .harnesskit/failures.json.tmp && \
        mv .harnesskit/failures.json.tmp .harnesskit/failures.json
    fi
  done
fi

# --- Detect repeated patterns (nudge) ---
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

case "$PRESET" in
  beginner)     THRESHOLD=2 ;;
  intermediate) THRESHOLD=3 ;;
  advanced)     THRESHOLD=5 ;;
  *)            THRESHOLD=3 ;;
esac

if [ -f ".harnesskit/failures.json" ]; then
  REPEATED=$(jq -r --argjson t "$THRESHOLD" '.failures[] | select(.status == "open" and .occurrences >= $t) | .pattern' .harnesskit/failures.json 2>/dev/null || echo "")
  if [ -n "$REPEATED" ]; then
    echo ""
    echo "💡 Repeated error patterns detected:"
    echo "$REPEATED" | while IFS= read -r p; do
      echo "   - $p"
    done
    echo "   Run /harnesskit:insights for analysis"
  fi
fi

rm -f .harnesskit/session-start-time.txt
