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
echo "=== Skill seed templates ==="
check_file "$TEMPLATES/skills/nextjs/nextjs-conventions.md" "nextjs-conventions"
check_file "$TEMPLATES/skills/nextjs/nextjs-testing.md" "nextjs-testing"
check_file "$TEMPLATES/skills/python-fastapi/fastapi-conventions.md" "fastapi-conventions"
check_file "$TEMPLATES/skills/python-fastapi/fastapi-testing.md" "fastapi-testing"
check_file "$TEMPLATES/skills/common/typescript-standards.md" "typescript-standards"
check_file "$TEMPLATES/skills/common/git-workflow.md" "git-workflow"
check_file "$TEMPLATES/skills/common/code-style.md" "code-style"
check_file "$TEMPLATES/skills/generic/general-conventions.md" "general-conventions"

echo ""
echo "=== Agent templates ==="
check_file "$TEMPLATES/agents/planner.md" "planner"
check_file "$TEMPLATES/agents/reviewer.md" "reviewer"
check_file "$TEMPLATES/agents/researcher.md" "researcher"
check_file "$TEMPLATES/agents/debugger.md" "debugger"

echo ""
echo "=== Hook scripts ==="
HOOKS="$SCRIPT_DIR/../hooks"
check_file "$HOOKS/post-edit-lint.sh" "post-edit-lint.sh"
check_file "$HOOKS/post-edit-typecheck.sh" "post-edit-typecheck.sh"
check_file "$HOOKS/pre-commit-test.sh" "pre-commit-test.sh"

echo ""
echo "=== Skill files ==="
SKILLS="$SCRIPT_DIR/../skills"
check_file "$SKILLS/setup.md" "setup.md"
check_file "$SKILLS/init.md" "init.md"
check_file "$SKILLS/test.md" "test.md"
check_file "$SKILLS/lint.md" "lint.md"
check_file "$SKILLS/typecheck.md" "typecheck.md"
check_file "$SKILLS/dev.md" "dev.md"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
