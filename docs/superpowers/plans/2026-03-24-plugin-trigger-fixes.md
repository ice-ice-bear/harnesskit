# Plugin Trigger Review Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 gaps in HarnessKit plugin triggering: preset check for hooks, ${CLAUDE_PLUGIN_ROOT} path migration, marketplace discovery redesign, 3-step tool sequence collection, and plugin status verification.

**Architecture:** Each fix is an independent task that can be implemented and tested in isolation. Fix 1+5 are combined (preset check + path unification). All changes are backward-compatible — hooks fallback to dirname when CLAUDE_PLUGIN_ROOT is unset.

**Tech Stack:** Bash/jq (hooks, scripts), Markdown (skills), JSON (templates, fixtures)

**Spec:** `docs/superpowers/specs/2026-03-24-plugin-trigger-review-fixes.md`

---

### Task 1: Add preset check to post-edit-lint.sh + path unification

**Files:**
- Modify: `hooks/post-edit-lint.sh:9-11` (insert preset check block after TOOL check)
- Test: `tests/test-hooks-integration.sh` (add preset check assertions)

- [ ] **Step 1: Write the failing test**

Add a new phase to `tests/test-hooks-integration.sh` that verifies post-edit-lint respects the advanced preset:

```bash
# Append to tests/test-hooks-integration.sh, before the cleanup

echo "=== Phase 5: Post-edit-lint preset check ==="
TMPDIR5=$(mktemp -d)
mkdir -p "$TMPDIR5/.harnesskit"
# Use advanced preset — postEditLint: false
cat > "$TMPDIR5/.harnesskit/config.json" <<'CONF'
{"preset": "advanced"}
CONF
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' > "$TMPDIR5/input.json"

EXIT5=0
export CLAUDE_PLUGIN_ROOT="$SCRIPT_DIR/.."
(cd "$TMPDIR5" && cat input.json | bash "$HOOKS/post-edit-lint.sh") >/dev/null 2>&1 || EXIT5=$?
check "post-edit-lint exits early on advanced preset" "[ $EXIT5 -eq 0 ]"
# Verify no lint was actually attempted (would fail since no eslint in temp dir)
unset CLAUDE_PLUGIN_ROOT

rm -rf "$TMPDIR5"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-hooks-integration.sh`
Expected: FAIL — current post-edit-lint.sh has no preset check, will try to run eslint

- [ ] **Step 3: Implement the change**

Edit `hooks/post-edit-lint.sh` — insert after line 11 (`exit 0` for non-Edit/Write) and before line 13 (`FILE=...`):

```bash
# Preset check: respect devHooks.postEditLint setting
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# Intentionally // true: lint is enabled by default (opt-out)
ENABLED=$(jq -r '.devHooks.postEditLint // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-hooks-integration.sh`
Expected: PASS — all phases including new Phase 5

- [ ] **Step 5: Commit**

```bash
git add hooks/post-edit-lint.sh tests/test-hooks-integration.sh
git commit -m "fix: add preset check to post-edit-lint.sh + CLAUDE_PLUGIN_ROOT fallback"
```

---

### Task 2: Add preset check to post-edit-typecheck.sh + path unification

**Files:**
- Modify: `hooks/post-edit-typecheck.sh:8-10` (insert preset check block after TOOL check)
- Test: `tests/test-hooks-integration.sh` (add Phase 6)

- [ ] **Step 1: Write the failing test**

Add Phase 6 to `tests/test-hooks-integration.sh`:

```bash
echo "=== Phase 6: Post-edit-typecheck preset check ==="
TMPDIR6=$(mktemp -d)
mkdir -p "$TMPDIR6/.harnesskit"
cat > "$TMPDIR6/.harnesskit/config.json" <<'CONF'
{"preset": "advanced"}
CONF
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' > "$TMPDIR6/input.json"

EXIT6=0
export CLAUDE_PLUGIN_ROOT="$SCRIPT_DIR/.."
(cd "$TMPDIR6" && cat input.json | bash "$HOOKS/post-edit-typecheck.sh") >/dev/null 2>&1 || EXIT6=$?
check "post-edit-typecheck exits early on advanced preset" "[ $EXIT6 -eq 0 ]"
unset CLAUDE_PLUGIN_ROOT

rm -rf "$TMPDIR6"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-hooks-integration.sh`
Expected: FAIL on Phase 6

- [ ] **Step 3: Implement the change**

Edit `hooks/post-edit-typecheck.sh` — insert after line 10 (`exit 0` for non-Edit/Write) and before line 12 (`FILE=...`):

```bash
# Preset check: respect devHooks.postEditTypecheck setting
PRESET="intermediate"
[ -f ".harnesskit/config.json" ] && \
  PRESET=$(jq -r '.preset // "intermediate"' .harnesskit/config.json 2>/dev/null || echo "intermediate")

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# Intentionally // true: typecheck is enabled by default (opt-out)
ENABLED=$(jq -r '.devHooks.postEditTypecheck // true' "$PLUGIN_DIR/templates/presets/$PRESET.json" 2>/dev/null || echo "true")
[ "$ENABLED" != "true" ] && exit 0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-hooks-integration.sh`
Expected: PASS — all 6 phases

- [ ] **Step 5: Commit**

```bash
git add hooks/post-edit-typecheck.sh tests/test-hooks-integration.sh
git commit -m "fix: add preset check to post-edit-typecheck.sh + CLAUDE_PLUGIN_ROOT fallback"
```

---

### Task 3: Unify PLUGIN_DIR in guardrails.sh and pre-commit-test.sh

**Files:**
- Modify: `hooks/guardrails.sh:18`
- Modify: `hooks/pre-commit-test.sh:18`
- Test: `tests/test-guardrails.sh` (add CLAUDE_PLUGIN_ROOT test)

- [ ] **Step 1: Write the failing test**

Add a test case to `tests/test-guardrails.sh` that runs with `CLAUDE_PLUGIN_ROOT` set:

```bash
echo ""
echo "=== CLAUDE_PLUGIN_ROOT fallback ==="
TMPDIR_R=$(mktemp -d)
mkdir -p "$TMPDIR_R/.harnesskit"
cp "$SCRIPT_DIR/fixtures/mock-config-intermediate.json" "$TMPDIR_R/.harnesskit/config.json"

# Test with CLAUDE_PLUGIN_ROOT explicitly set
ACTUAL_EXIT=0
export CLAUDE_PLUGIN_ROOT="$SCRIPT_DIR/.."
(cd "$TMPDIR_R" && cat "$INPUTS/bash-sudo.json" | bash "$HOOK") >/dev/null 2>&1 || ACTUAL_EXIT=$?
unset CLAUDE_PLUGIN_ROOT

if [ "$ACTUAL_EXIT" -eq 2 ]; then
  echo "  ✅ CLAUDE_PLUGIN_ROOT works (exit=$ACTUAL_EXIT)"
  PASS=$((PASS + 1))
else
  echo "  ❌ CLAUDE_PLUGIN_ROOT failed (expected exit=2, got=$ACTUAL_EXIT)"
  FAIL=$((FAIL + 1))
fi

rm -rf "$TMPDIR_R"
```

- [ ] **Step 2: Run test to verify it passes (already works with dirname fallback)**

Run: `bash tests/test-guardrails.sh`
Expected: PASS — dirname fallback still works, this verifies the env var path also works

- [ ] **Step 3: Implement the change**

Edit `hooks/guardrails.sh` line 18:
```diff
- PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
+ PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
```

Edit `hooks/pre-commit-test.sh` line 18:
```diff
- PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
+ PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
```

- [ ] **Step 4: Run all hook tests**

Run: `bash tests/test-guardrails.sh && bash tests/test-hooks-integration.sh`
Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add hooks/guardrails.sh hooks/pre-commit-test.sh tests/test-guardrails.sh
git commit -m "refactor: unify PLUGIN_DIR to use CLAUDE_PLUGIN_ROOT with dirname fallback"
```

---

### Task 4: Update skills to use ${CLAUDE_PLUGIN_ROOT}

**Files:**
- Modify: `skills/setup/SKILL.md:16`
- Modify: `skills/init/SKILL.md:56-61` (hook registration section)

- [ ] **Step 1: Edit setup/SKILL.md**

Line 16 — change `claude plugin path harnesskit` to `${CLAUDE_PLUGIN_ROOT}`:

```diff
- bash "$(claude plugin path harnesskit)/scripts/detect-repo.sh" "$(pwd)"
+ bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-repo.sh" "$(pwd)"
```

- [ ] **Step 2: Edit init/SKILL.md hook registration section**

In the "Register Hooks in .claude/settings.json" section (around line 53-61), add a note about the hook command format:

```markdown
Hook commands use `${CLAUDE_PLUGIN_ROOT}` which is auto-substituted by Claude Code:
- SessionStart: `${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh`
- PreToolUse: `${CLAUDE_PLUGIN_ROOT}/hooks/guardrails.sh`
- Stop: `${CLAUDE_PLUGIN_ROOT}/hooks/session-end.sh`
- PostToolUse: `${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-lint.sh`, `${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-typecheck.sh`
- PreToolUse: `${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit-test.sh`
```

- [ ] **Step 3: Also fix init/SKILL.md step numbering**

Renumber section "### 6. Summary" → "### 4. Summary" (currently jumps from 3 to 6).

- [ ] **Step 4: Commit**

```bash
git add skills/setup/SKILL.md skills/init/SKILL.md
git commit -m "refactor: migrate skills from 'claude plugin path' to CLAUDE_PLUGIN_ROOT"
```

---

### Task 5: Create marketplace-recommendations.json

**Files:**
- Create: `templates/marketplace-recommendations.json`
- Test: `tests/test-init-templates.sh` (add recommendations.json check)

- [ ] **Step 1: Write the failing test**

Add to `tests/test-init-templates.sh` before the Results section:

```bash
echo ""
echo "=== Marketplace recommendations ==="
check_json "$TEMPLATES/marketplace-recommendations.json" "marketplace-recommendations.json"

# Schema checks
RECS_SCHEMA=$(jq -e '.schemaVersion and .recommendations and .conditions' "$TEMPLATES/marketplace-recommendations.json" 2>/dev/null && echo "valid" || echo "invalid")
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-init-templates.sh`
Expected: FAIL — file doesn't exist yet

- [ ] **Step 3: Create the recommendations file**

Write `templates/marketplace-recommendations.json` with the exact content from the spec (11 recommendations across lsp, general, review, security, integrations).

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-init-templates.sh`
Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add templates/marketplace-recommendations.json tests/test-init-templates.sh
git commit -m "feat: add verified marketplace-recommendations.json for plugin discovery"
```

---

### Task 6: Create update-recommendations.sh crawl script

**Files:**
- Create: `scripts/update-recommendations.sh`
- Create: `tests/test-update-recommendations.sh`

- [ ] **Step 1: Write the test**

Create `tests/test-update-recommendations.sh`:

```bash
#!/bin/bash
# test-update-recommendations.sh — Verify crawl script output schema
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/update-recommendations.sh"
RECS="$SCRIPT_DIR/../templates/marketplace-recommendations.json"
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

echo "=== Script exists and is executable ==="
check "script exists" "$([ -f "$SCRIPT" ] && echo yes || echo no)" "yes"

echo ""
echo "=== Output file schema (existing) ==="
check "has schemaVersion" "$(jq -r '.schemaVersion' "$RECS" 2>/dev/null)" "1.0"
check "has recommendations array" "$(jq '.recommendations | type' "$RECS" 2>/dev/null)" '"array"'
check "has conditions object" "$(jq '.conditions | type' "$RECS" 2>/dev/null)" '"object"'
check "has lastUpdated" "$(jq -e '.lastUpdated' "$RECS" >/dev/null 2>&1 && echo yes || echo no)" "yes"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Create the script**

Write `scripts/update-recommendations.sh` with the exact content from the spec. Make it executable.

- [ ] **Step 3: Run the test**

Run: `bash tests/test-update-recommendations.sh`
Expected: PASS — schema validation against existing recommendations.json

- [ ] **Step 4: Commit**

```bash
chmod +x scripts/update-recommendations.sh
git add scripts/update-recommendations.sh tests/test-update-recommendations.sh
git commit -m "feat: add update-recommendations.sh for marketplace crawling"
```

---

### Task 7: Rewrite init/SKILL.md marketplace section

**Files:**
- Modify: `skills/init/SKILL.md:64-102` (replace "Marketplace Plugin Discovery" section)

- [ ] **Step 1: Read current file to identify exact replacement boundaries**

The section to replace starts at `### 3. Marketplace Plugin Discovery` (line 64) and ends before `### 6. Summary` (line 104).

- [ ] **Step 2: Replace the section**

Replace lines 64-102 with the new marketplace discovery logic from the spec section 2-3. Key changes:
- Reference `${CLAUDE_PLUGIN_ROOT}/templates/marketplace-recommendations.json` instead of "Search marketplace"
- Add condition matching logic (language → lsp, git → general/review, framework → security)
- Add fallback chain (file → live fetch → hardcoded minimal)
- Add "/plugin → Discover tab" guidance
- Use `/plugin install {name}@claude-plugins-official` format

- [ ] **Step 3: Commit**

```bash
git add skills/init/SKILL.md
git commit -m "feat: rewrite init marketplace discovery to use verified recommendations"
```

---

### Task 8: Update insights/SKILL.md plugin_recommendation

**Files:**
- Modify: `skills/insights/SKILL.md` (plugin_recommendation section, around line 183-193)

- [ ] **Step 1: Read and locate the section**

Find the `plugin_recommendation` proposal type section and the "v2a enhanced" note.

- [ ] **Step 2: Add recommendations.json reference**

After the existing `plugin_recommendation` trigger conditions, add:

```markdown
**Data source for recommendations:**
1. Read `${CLAUDE_PLUGIN_ROOT}/templates/marketplace-recommendations.json`
2. Cross-reference with `config.json` `installedPlugins` — only recommend uninstalled plugins
3. Match session usage patterns against recommendation conditions
4. Provide exact install command: `/plugin install {name}@claude-plugins-official`
```

- [ ] **Step 3: Commit**

```bash
git add skills/insights/SKILL.md
git commit -m "feat: add recommendations.json reference to insights plugin_recommendation"
```

---

### Task 9: Rewrite session-end.sh tool sequence collection

**Files:**
- Modify: `hooks/session-end.sh:46-78` (toolCallSequences + rawToolSequence)
- Modify: `hooks/session-end.sh:98-122` (jq -n output template)
- Modify: `tests/fixtures/mock-session-v2a.jsonl` (extend with repeated 3-step pattern)
- Modify: `tests/test-session-end-v2a.sh` (rewrite Group 1)

- [ ] **Step 1: Extend the test fixture**

Add repeated 3-step patterns to `tests/fixtures/mock-session-v2a.jsonl`. Insert before the plugin_invocation lines (after line 10):

```jsonl
{"type":"tool_call","tool":"Bash","summary":"tsc --noEmit","timestamp":"14:57"}
{"type":"tool_call","tool":"Edit","summary":"fix type in auth.ts","timestamp":"14:59"}
{"type":"tool_call","tool":"Bash","summary":"tsc --noEmit","timestamp":"15:01"}
```

This creates a repeated 3-step pattern: `Bash:tsc --noEmit → Edit:fix type in auth.ts → Bash:tsc --noEmit` appearing 2 times.

**IMPORTANT**: Adding 3 tool_call lines changes total tool count from 9 to 12. This affects Group 2 (task time distribution) ratios. New expected values:
- coding = 9/12 = 0.75 (was 6/9 = 0.667)
- debugging = 1/12 = 0.083 (was 1/9 = 0.111)
- research = 2/12 = 0.167 (was 2/9 = 0.222)

- [ ] **Step 1b: Update Group 2 test assertions**

In `tests/test-session-end-v2a.sh` Group 2, update the expected ratio bounds:

```bash
# coding = Bash:tsc(5) + Edit(3) + Write(1) = 9/12 = 0.75
CODING_OK=$(jq -rn --argjson v "$CODING" 'if $v > 0.74 and $v < 0.76 then "true" else "false" end' 2>/dev/null || echo "false")
check "coding ratio ~0.75" "$CODING_OK" "true"

# debugging = Bash:npm test(1) = 1/12 ≈ 0.083
DEBUGGING_OK=$(jq -rn --argjson v "$DEBUGGING" 'if $v > 0.08 and $v < 0.09 then "true" else "false" end' 2>/dev/null || echo "false")
check "debugging ratio ~0.083" "$DEBUGGING_OK" "true"

# research = WebSearch(2) = 2/12 ≈ 0.167
RESEARCH_OK=$(jq -rn --argjson v "$RESEARCH" 'if $v > 0.16 and $v < 0.17 then "true" else "false" end' 2>/dev/null || echo "false")
check "research ratio ~0.167" "$RESEARCH_OK" "true"
```

- [ ] **Step 2: Rewrite test Group 1 assertions**

Replace `tests/test-session-end-v2a.sh` Group 1 (lines 38-46) with:

```bash
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bash tests/test-session-end-v2a.sh`
Expected: FAIL — session-end.sh still uses 2-step bare names

- [ ] **Step 4: Implement toolCallSequences rewrite**

In `hooks/session-end.sh`, replace the tool sequence detection block (lines 51-62) with:

```bash
    # --- 3-step sliding window with tool:summary format (v2a spec) ---
    TOOL_CALL_SEQUENCES=$(echo "$TOOL_LINES" | jq -s '
      [.[] | (.tool + ":" + ((.summary // "")[0:30]))] as $labeled |
      if ($labeled | length) < 3 then [] else
        (reduce range(0; ($labeled | length) - 2) as $i (
          {};
          ($labeled[$i] + " → " + $labeled[$i+1] + " → " + $labeled[$i+2]) as $triple |
          .[$triple] = ((.[$triple] // 0) + 1)
        )) as $triples |
        [$triples | to_entries[] |
          (.key | split(" → ")) as $seq |
          {sequence: $seq, count: .value, context: "repeated 3-step pattern"}
        ]
      end
    ' 2>/dev/null || echo "[]")
```

- [ ] **Step 5: Add rawToolSequence extraction**

After the TOOL_CALL_SEQUENCES block, before taskTimeDistribution, add:

```bash
    # --- Raw tool sequence for insights arbitrary-length analysis ---
    RAW_TOOL_SEQ=$(echo "$TOOL_LINES" | jq -s '[.[] | (.tool + ":" + ((.summary // "")[0:30]))]' 2>/dev/null || echo "[]")
```

Initialize `RAW_TOOL_SEQ="[]"` near line 25 (alongside other initializations).

- [ ] **Step 6: Update jq -n output template**

In the `jq -n` call (lines 98-122), add:
- Parameter: `--argjson raw "$RAW_TOOL_SEQ"`
- Field in JSON template: `rawToolSequence: $raw` (after `toolCallSequences: $seqs`)

- [ ] **Step 7: Run test to verify it passes**

Run: `bash tests/test-session-end-v2a.sh`
Expected: all PASS

- [ ] **Step 8: Run full test suite to verify backward compatibility**

Run: `for t in tests/test-*.sh; do echo "--- $t ---"; bash "$t"; done`
Expected: all tests PASS (Group 4 backward compat still works)

- [ ] **Step 9: Commit**

```bash
git add hooks/session-end.sh tests/test-session-end-v2a.sh tests/fixtures/mock-session-v2a.jsonl
git commit -m "feat: upgrade tool sequence to 3-step sliding window with tool:summary format"
```

---

### Task 10: Update status/SKILL.md with plugin verification

**Files:**
- Modify: `skills/status/SKILL.md` (add Plugin Installation Verification section)

- [ ] **Step 1: Read current file**

Read `skills/status/SKILL.md` to identify where to insert the new section.

- [ ] **Step 2: Add verification section**

After step 1 ("Read config.json..."), insert the Plugin Installation Verification section from the spec:

```markdown
## Plugin Installation Verification

After reading installedPlugins from config.json:

1. Check if `$HOME/.claude/plugins/cache/` directory exists
2. If it exists, for each plugin in installedPlugins:
   - Use glob search: `find $HOME/.claude/plugins/cache/ -maxdepth 2 -name "{plugin-name}" -type d`
   - Cache path may vary by Claude Code version — name-based glob is safest
3. Report status per plugin:
   - ✅ {name} — installed and cached
   - ⚠️ {name} — in config but not found in cache (may need reinstall)
   - If glob search fails or returns unexpected results, fall back to "unverified"

If cache directory doesn't exist, skip verification and display config as-is with note:
  "(plugin cache not found — verification skipped)"

If installedPlugins is empty, display:
  "Marketplace Plugins: none installed"

If mismatches found, suggest:
  "Run `/plugin install {name}@claude-plugins-official` to reinstall missing plugins,
   or update .harnesskit/config.json to remove stale entries."
```

- [ ] **Step 3: Update output format**

Replace the `Marketplace Plugins:` line in the output template with the verified format showing ✅/⚠️ per plugin.

- [ ] **Step 4: Commit**

```bash
git add skills/status/SKILL.md
git commit -m "feat: add plugin installation verification to status skill"
```

---

### Task 11: Final integration test + cleanup

**Files:**
- Test: all test files

- [ ] **Step 1: Run full test suite**

```bash
for t in tests/test-*.sh; do echo "=== $t ==="; bash "$t"; echo; done
```

Expected: ALL PASS

- [ ] **Step 2: Verify all changed files are committed**

```bash
git status
git log --oneline -10
```

Expected: clean working tree, ~10 commits for this feature

- [ ] **Step 3: Summary commit (optional squash)**

If all tests pass, the implementation is complete. Each task has its own commit for traceability.
