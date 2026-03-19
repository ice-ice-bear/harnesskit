#!/bin/bash
# session-start.sh — SessionStart hook: compile and output session briefing
# Zero token cost — all file reads, no Claude calls
set -euo pipefail

# Record start time
date -u +"%Y-%m-%dT%H:%M:%SZ" > .harnesskit/session-start-time.txt 2>/dev/null || true

# Load preset
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

# Read progress
PROGRESS=""
[ -f "progress/claude-progress.txt" ] && \
  PROGRESS=$(cat progress/claude-progress.txt 2>/dev/null || echo "No previous progress")

# Read feature list
TOTAL=0
DONE=0
if [ -f "docs/feature_list.json" ]; then
  TOTAL=$(jq '.features | length' docs/feature_list.json 2>/dev/null || echo 0)
  DONE=$(jq '[.features[] | select(.passes == true)] | length' docs/feature_list.json 2>/dev/null || echo 0)
fi

# Read recent failures
FAILURES=""
if [ -f ".harnesskit/failures.json" ]; then
  FAILURES=$(jq -r '.failures[] | select(.status == "open") | "  - [\(.id)] \(.pattern) (\(.occurrences)x)"' .harnesskit/failures.json 2>/dev/null || echo "")
fi

# Git log
GITLOG=""
[ -d ".git" ] && GITLOG=$(git log --oneline -5 2>/dev/null || echo "")

# Output based on preset
case "$PRESET" in
  beginner)
    cat <<BRIEFING
═══ HarnessKit Session Briefing ═══

📋 Progress:
$PROGRESS

📊 Feature Status: $DONE/$TOTAL completed

⚠️  Active Failures:
${FAILURES:-  None}

🔧 Next Steps:
  1. Run existing tests to verify baseline
  2. Select next feature from feature_list.json
  3. Write feature ID to .harnesskit/current-feature.txt
  4. Implement and test

📝 Recent Commits:
$GITLOG

════════════════════════════════════
BRIEFING
    ;;
  intermediate)
    cat <<BRIEFING
═══ HarnessKit Session Briefing ═══
📋 Progress: $DONE/$TOTAL features done
${FAILURES:+⚠️  Failures:
$FAILURES}
📝 Recent: $(echo "$GITLOG" | head -3)
════════════════════════════════════
BRIEFING
    ;;
  advanced)
    echo "[HK] $DONE/$TOTAL done${FAILURES:+ | ⚠️ open failures}"
    ;;
esac
