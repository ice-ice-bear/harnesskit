#!/bin/bash
# test-architect-skill.sh — Validate architect skill structure and references
set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL + 1)); }

echo "=== Architect Skill Tests ==="

# --- Skill file exists and has correct frontmatter ---
echo ""
echo "--- Skill File Structure ---"

if [ -f "$REPO_DIR/skills/architect/SKILL.md" ]; then
  pass "skills/architect/SKILL.md exists"
else
  fail "skills/architect/SKILL.md missing"
fi

if grep -q "^name: architect" "$REPO_DIR/skills/architect/SKILL.md" 2>/dev/null; then
  pass "SKILL.md has name: architect"
else
  fail "SKILL.md missing name: architect"
fi

if grep -q "^user_invocable: true" "$REPO_DIR/skills/architect/SKILL.md" 2>/dev/null; then
  pass "SKILL.md is user_invocable"
else
  fail "SKILL.md not user_invocable"
fi

if grep -q "^description:" "$REPO_DIR/skills/architect/SKILL.md" 2>/dev/null; then
  pass "SKILL.md has description"
else
  fail "SKILL.md missing description"
fi

# --- Command file exists ---
echo ""
echo "--- Command Registration ---"

if [ -f "$REPO_DIR/commands/architect.md" ]; then
  pass "commands/architect.md exists"
else
  fail "commands/architect.md missing"
fi

# --- Reference files exist ---
echo ""
echo "--- Reference Documents ---"

if [ -f "$REPO_DIR/templates/references/agent-design-patterns.md" ]; then
  pass "agent-design-patterns.md exists"
else
  fail "agent-design-patterns.md missing"
fi

PATTERNS_LINES=$(wc -l < "$REPO_DIR/templates/references/agent-design-patterns.md" 2>/dev/null || echo "0")
if [ "$PATTERNS_LINES" -gt 100 ]; then
  pass "agent-design-patterns.md has $PATTERNS_LINES lines (>100)"
else
  fail "agent-design-patterns.md too short: $PATTERNS_LINES lines"
fi

if [ -f "$REPO_DIR/templates/references/orchestrator-templates.md" ]; then
  pass "orchestrator-templates.md exists"
else
  fail "orchestrator-templates.md missing"
fi

ORCH_LINES=$(wc -l < "$REPO_DIR/templates/references/orchestrator-templates.md" 2>/dev/null || echo "0")
if [ "$ORCH_LINES" -gt 80 ]; then
  pass "orchestrator-templates.md has $ORCH_LINES lines (>80)"
else
  fail "orchestrator-templates.md too short: $ORCH_LINES lines"
fi

# --- 6 patterns referenced ---
echo ""
echo "--- Pattern Coverage ---"

for pattern in "Pipeline" "Fan-out" "Expert Pool" "Producer-Reviewer" "Supervisor" "Hierarchical"; do
  if grep -qi "$pattern" "$REPO_DIR/templates/references/agent-design-patterns.md" 2>/dev/null; then
    pass "Pattern documented: $pattern"
  else
    fail "Pattern missing: $pattern"
  fi
done

# --- Skill references the reference files ---
echo ""
echo "--- Skill-Reference Integration ---"

if grep -q "agent-design-patterns.md" "$REPO_DIR/skills/architect/SKILL.md" 2>/dev/null; then
  pass "Skill references agent-design-patterns.md"
else
  fail "Skill does not reference agent-design-patterns.md"
fi

if grep -q "orchestrator-templates.md" "$REPO_DIR/skills/architect/SKILL.md" 2>/dev/null; then
  pass "Skill references orchestrator-templates.md"
else
  fail "Skill does not reference orchestrator-templates.md"
fi

# --- Orchestrator agent mentions architect flow ---
echo ""
echo "--- Orchestrator Integration ---"

if grep -qi "architect" "$REPO_DIR/agents/orchestrator/AGENT.md" 2>/dev/null; then
  pass "Orchestrator agent references architect flow"
else
  fail "Orchestrator agent missing architect flow"
fi

# --- plugin.json has agent-team keyword ---
echo ""
echo "--- Plugin Metadata ---"

if jq -e '.keywords | index("agent-team")' "$REPO_DIR/.claude-plugin/plugin.json" >/dev/null 2>&1; then
  pass "plugin.json has agent-team keyword"
else
  fail "plugin.json missing agent-team keyword"
fi

if jq -e '.homepage' "$REPO_DIR/.claude-plugin/plugin.json" >/dev/null 2>&1; then
  pass "plugin.json has homepage"
else
  fail "plugin.json missing homepage"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
