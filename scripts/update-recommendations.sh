#!/bin/bash
# update-recommendations.sh — 공식 마켓플레이스에서 추천 목록 갱신
# 이 스크립트는 개발자가 수동 실행하거나 CI에서 주기적 실행
# ${CLAUDE_PLUGIN_ROOT}이 아닌 dirname 사용: 플러그인 컨텍스트 외부에서도 실행 가능해야 하므로
set -euo pipefail

MARKETPLACE_URL="https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$SCRIPT_DIR/../templates/marketplace-recommendations.json"

# 1. Fetch marketplace.json
RAW=$(curl -sL "$MARKETPLACE_URL")
if [ -z "$RAW" ]; then
  echo "❌ Failed to fetch marketplace.json" >&2
  exit 1
fi

# 2. Schema validation
PLUGIN_COUNT=$(echo "$RAW" | jq '.plugins | length' 2>/dev/null || echo "0")
if [ "$PLUGIN_COUNT" = "0" ]; then
  echo "❌ marketplace.json has no plugins or unexpected schema" >&2
  echo "   Expected: {plugins: [{name, description, ...}]}" >&2
  exit 1
fi
echo "📦 Found $PLUGIN_COUNT plugins in marketplace"

# 3. Extract all plugins with metadata
ALL_PLUGINS=$(echo "$RAW" | jq '[.plugins[] | {
  name: .name,
  description: (.description // ""),
  category: (.category // "uncategorized"),
  keywords: (.keywords // []),
  tags: (.tags // [])
}]')

# 4. Auto-classify
LSP_NAMES=$(echo "$ALL_PLUGINS" | jq -r '[.[] | select(.name | endswith("-lsp")) | .name] | join(", ")')
SECURITY_NAMES=$(echo "$ALL_PLUGINS" | jq -r '[.[] | select(
  .category == "Security" or
  (.keywords // [] | any(. == "security")) or
  (.name | test("security|semgrep|aikido"))
) | .name] | join(", ")')
REVIEW_NAMES=$(echo "$ALL_PLUGINS" | jq -r '[.[] | select(
  (.name | test("review|simplif")) or
  (.description | test("review|code quality"; "i"))
) | .name] | join(", ")')

echo ""
echo "📋 Auto-classified plugins:"
echo "   LSP: $LSP_NAMES"
echo "   Security: $SECURITY_NAMES"
echo "   Review: $REVIEW_NAMES"
echo ""

# 5. Preserve existing recommendations (수동 조건 매핑 유지)
if [ -f "$OUTPUT" ]; then
  EXISTING_RECS=$(jq '.recommendations // []' "$OUTPUT")
  EXISTING_CONDITIONS=$(jq '.conditions // {}' "$OUTPUT")
else
  EXISTING_RECS='[]'
  EXISTING_CONDITIONS='{}'
fi

# 6. 갱신: lastUpdated + allPlugins, recommendations + conditions 보존
jq -n \
  --arg date "$(date -u +%Y-%m-%d)" \
  --argjson all "$ALL_PLUGINS" \
  --argjson recs "$EXISTING_RECS" \
  --argjson conditions "$EXISTING_CONDITIONS" \
  '{
    schemaVersion: "1.0",
    lastUpdated: $date,
    source: "https://github.com/anthropics/claude-plugins-official",
    allPlugins: $all,
    recommendations: $recs,
    conditions: $conditions
  }' > "$OUTPUT"

echo "✅ Updated $OUTPUT — $PLUGIN_COUNT plugins indexed, $(echo "$EXISTING_RECS" | jq length) recommendations preserved"
echo ""
echo "💡 Review auto-classified plugins above and manually add new entries to"
echo "   recommendations[] in $OUTPUT with appropriate 'when' conditions."
