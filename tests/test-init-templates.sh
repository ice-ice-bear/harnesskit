#!/bin/bash
# test-init-templates.sh — Verify all templates exist and are valid
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES="$SCRIPT_DIR/../templates"
PASS=0
FAIL=0

check_file() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — NOT FOUND: $path"
    FAIL=$((FAIL + 1))
  fi
}

check_json() {
  local path="$1" label="$2"
  if [ -f "$path" ] && jq empty "$path" 2>/dev/null; then
    echo "  ✅ $label (valid JSON)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label — invalid or missing"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== CLAUDE.md templates ==="
check_file "$TEMPLATES/claude-md/base.md" "base.md"
check_file "$TEMPLATES/claude-md/nextjs.md" "nextjs.md"
check_file "$TEMPLATES/claude-md/python-fastapi.md" "python-fastapi.md"
check_file "$TEMPLATES/claude-md/react-vite.md" "react-vite.md"
check_file "$TEMPLATES/claude-md/python-django.md" "python-django.md"
check_file "$TEMPLATES/claude-md/generic.md" "generic.md"

echo ""
echo "=== .claudeignore templates ==="
check_file "$TEMPLATES/claudeignore/nextjs.txt" "nextjs.txt"
check_file "$TEMPLATES/claudeignore/python.txt" "python.txt"
check_file "$TEMPLATES/claudeignore/generic.txt" "generic.txt"

echo ""
echo "=== Preset JSON ==="
check_json "$TEMPLATES/presets/beginner.json" "beginner.json"
check_json "$TEMPLATES/presets/intermediate.json" "intermediate.json"
check_json "$TEMPLATES/presets/advanced.json" "advanced.json"

echo ""
echo "=== Feature list starter ==="
check_json "$TEMPLATES/feature-list/starter.json" "starter.json"

echo ""
echo "=== Hook scripts ==="
HOOKS="$SCRIPT_DIR/../hooks"
check_file "$HOOKS/post-edit-lint.sh" "post-edit-lint.sh"
check_file "$HOOKS/post-edit-typecheck.sh" "post-edit-typecheck.sh"
check_file "$HOOKS/pre-commit-test.sh" "pre-commit-test.sh"

echo ""
echo "=== Skill files ==="
SKILLS="$SCRIPT_DIR/../skills"
check_file "$SKILLS/setup/SKILL.md" "setup/SKILL.md"
check_file "$SKILLS/init/SKILL.md" "init/SKILL.md"
check_file "$SKILLS/test/SKILL.md" "test/SKILL.md"
check_file "$SKILLS/lint/SKILL.md" "lint/SKILL.md"
check_file "$SKILLS/typecheck/SKILL.md" "typecheck/SKILL.md"
check_file "$SKILLS/dev/SKILL.md" "dev/SKILL.md"

echo ""
echo "=== Marketplace recommendations ==="
check_json "$TEMPLATES/marketplace-recommendations.json" "marketplace-recommendations.json"

# Schema checks
RECS_SCHEMA=$(if jq -e '.schemaVersion and .recommendations and .conditions' "$TEMPLATES/marketplace-recommendations.json" >/dev/null 2>&1; then echo "valid"; else echo "invalid"; fi)
if [ "$RECS_SCHEMA" = "valid" ]; then
  echo "  ✅ recommendations.json has required fields"
  PASS=$((PASS + 1))
else
  echo "  ❌ recommendations.json missing required fields (schemaVersion, recommendations, conditions)"
  FAIL=$((FAIL + 1))
fi

# Every recommendation has plugin, category, when, description
RECS_ITEMS=$(jq '[.recommendations[] | select(.plugin and .category and .when and .description)] | length' "$TEMPLATES/marketplace-recommendations.json" 2>/dev/null || echo "0")
RECS_TOTAL=$(jq '.recommendations | length' "$TEMPLATES/marketplace-recommendations.json" 2>/dev/null || echo "0")
if [ "$RECS_ITEMS" = "$RECS_TOTAL" ] && [ "$RECS_TOTAL" != "0" ]; then
  echo "  ✅ all $RECS_TOTAL recommendations have required fields"
  PASS=$((PASS + 1))
else
  echo "  ❌ some recommendations missing fields ($RECS_ITEMS/$RECS_TOTAL valid)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
