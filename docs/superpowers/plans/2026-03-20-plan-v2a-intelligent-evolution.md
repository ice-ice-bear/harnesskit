# v2a — Intelligent Harness Evolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend HarnessKit's insights system to auto-generate skills, agents, hooks, and marketplace recommendations based on accumulated session data — making the harness self-evolving.

**Architecture:** Extend 6 existing files (no new plugin files). CLAUDE.md base template gains v2a event logging. session-end.sh gains tool call sequence detection, time distribution estimation, and plugin usage extraction. insights.md gains 3 new analysis dimensions and 4 new proposal types. apply.md gains execution paths for new proposals. status.md gains v2a dashboard fields. init.md gains v2a config schema initialization.

**Tech Stack:** Shell (bash), Markdown (skills), JSON, jq, Claude Code Plugin SDK

**Spec:** `docs/superpowers/specs/2026-03-20-harnesskit-v2a-design.md`

**Depends on:** v1 fully implemented (all 73 tests passing)

---

## File Structure

```
Modified files:
├── harnesskit/templates/claude-md/base.md      # Add v2a event logging protocol
├── harnesskit/hooks/session-end.sh             # Add tool_call/plugin extraction
├── harnesskit/skills/insights.md               # Add 3 dimensions, 4 proposal types
├── harnesskit/skills/apply.md                  # Add execution paths for new types
├── harnesskit/skills/status.md                 # Add v2a dashboard fields
└── harnesskit/skills/init.md                   # Add v2a config schema fields

Test files:
├── harnesskit/tests/test-session-end-v2a.sh    # v2a session-end extraction tests
└── harnesskit/tests/fixtures/
    ├── mock-session-v2a.jsonl                  # Fixture with tool_call + plugin events
    ├── mock-session-v2a-empty.jsonl            # Fixture with only v1 events (compat)
    └── mock-config-v2a.json                    # Config with v2a fields
```

---

### Task 1: base.md — v2a Event Logging Protocol

**Files:**
- Modify: `harnesskit/templates/claude-md/base.md`

- [ ] **Step 1: Read current base.md**

Current content has 3 sections: Session Start Protocol, Session End Protocol, Error Logging, Absolute Rules.

- [ ] **Step 2: Add v2a event logging section after Error Logging**

Append to `harnesskit/templates/claude-md/base.md` after the Error Logging section:

```markdown
## Tool Usage Logging (v2a — automatic)
- On major tool use, append to `.harnesskit/current-session.jsonl`:
  `{"type":"tool_call","tool":"ToolName","summary":"brief description","timestamp":"HH:MM"}`
  ※ Log Bash, Edit, Write, WebSearch, WebFetch only (skip Read, Glob, Grep)
  ※ One line per tool call, keep summary under 50 chars
- On marketplace plugin use:
  `{"type":"plugin_invocation","plugin":"plugin-name","feedback":["slug-keyword"]}`
  ※ feedback slugs: lowercase, hyphens, no spaces. Example: "missing-error-boundary"
  ※ Reuse existing slugs from prior session logs when same concept applies
```

- [ ] **Step 3: Verify base.md is still under recommended length**

The file should remain concise. Count lines — target under 40 lines total.

- [ ] **Step 4: Commit**

```bash
git add harnesskit/templates/claude-md/base.md
git commit -m "feat(v2a): add tool usage and plugin logging protocol to base.md"
```

---

### Task 2: Test Fixtures for v2a Session Data

**Files:**
- Create: `harnesskit/tests/fixtures/mock-session-v2a.jsonl`
- Create: `harnesskit/tests/fixtures/mock-session-v2a-empty.jsonl`
- Create: `harnesskit/tests/fixtures/mock-config-v2a.json`

- [ ] **Step 1: Create mock-session-v2a.jsonl with all v2a event types**

```jsonl
{"type":"error","pattern":"TypeError: Cannot read property 'id'","file":"src/auth.ts"}
{"type":"tool_call","tool":"Bash","summary":"tsc --noEmit","timestamp":"14:30"}
{"type":"tool_call","tool":"Edit","summary":"fix type in auth.ts","timestamp":"14:32"}
{"type":"tool_call","tool":"Bash","summary":"tsc --noEmit","timestamp":"14:34"}
{"type":"tool_call","tool":"Edit","summary":"fix type in user.ts","timestamp":"14:36"}
{"type":"tool_call","tool":"Bash","summary":"tsc --noEmit","timestamp":"14:38"}
{"type":"tool_call","tool":"Bash","summary":"npm test","timestamp":"14:40"}
{"type":"tool_call","tool":"Write","summary":"create api handler","timestamp":"14:45"}
{"type":"tool_call","tool":"WebSearch","summary":"stripe api docs","timestamp":"14:50"}
{"type":"tool_call","tool":"WebSearch","summary":"stripe webhook setup","timestamp":"14:55"}
{"type":"plugin_invocation","plugin":"review","feedback":["missing-error-boundary","no-loading-state"]}
{"type":"plugin_invocation","plugin":"simplify","feedback":[]}
{"type":"feature_done","id":"feat-003"}
```

This fixture contains:
- 1 error event (v1 compat)
- 9 tool_call events: Bash(3 tsc + 1 test) + Edit(2) + Write(1) + WebSearch(2)
- The "Bash→Edit→Bash" tool-name pattern repeats, forming a detectable sequence
- Sequence detection matches by **tool name only** (ignoring summary variance)
- 2 plugin_invocation events (review with feedback, simplify without)
- 1 feature_done event (v1 compat)

- [ ] **Step 2: Create mock-session-v2a-empty.jsonl (v1-only events)**

```jsonl
{"type":"error","pattern":"ReferenceError: foo is not defined","file":"src/index.ts"}
{"type":"feature_fail","id":"feat-002"}
```

This tests backward compatibility — no v2a events present.

- [ ] **Step 3: Create mock-config-v2a.json**

```json
{
  "preset": "intermediate",
  "schemaVersion": "2.0",
  "detectedAt": "2026-03-20",
  "installedPlugins": ["simplify", "review"],
  "uncoveredAreas": ["error-handling", "performance"],
  "reviewInternalization": {
    "stage": "marketplace_only",
    "supplementSince": null,
    "coveragePercent": null
  },
  "customHooks": [],
  "customSkills": [],
  "customAgents": [],
  "removedPlugins": []
}
```

- [ ] **Step 4: Commit**

```bash
git add harnesskit/tests/fixtures/mock-session-v2a.jsonl harnesskit/tests/fixtures/mock-session-v2a-empty.jsonl harnesskit/tests/fixtures/mock-config-v2a.json
git commit -m "test(v2a): add session data fixtures for v2a events"
```

---

### Task 3: session-end.sh — v2a Data Extraction (TDD)

**Files:**
- Create: `harnesskit/tests/test-session-end-v2a.sh`
- Modify: `harnesskit/hooks/session-end.sh`

- [ ] **Step 1: Write failing tests for tool call sequence detection**

Create `harnesskit/tests/test-session-end-v2a.sh`:

```bash
#!/bin/bash
# test-session-end-v2a.sh — Tests for v2a session-end extraction
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/session-end.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
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

# Setup temp dir simulating a project
setup_project() {
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/.harnesskit/session-logs"
  cp "$FIXTURES/mock-config-v2a.json" "$TMPDIR/.harnesskit/config.json"
  echo '{"failures":[]}' > "$TMPDIR/.harnesskit/failures.json"
  echo "2026-03-20T14:00:00Z" > "$TMPDIR/.harnesskit/session-start-time.txt"
  echo "feat-003" > "$TMPDIR/.harnesskit/current-feature.txt"
  cd "$TMPDIR"
  git init -q && git commit --allow-empty -m "init" -q
}

cleanup() {
  cd /
  rm -rf "$TMPDIR"
}

# === Test: v2a JSONL produces toolCallSequences ===
echo "=== v2a: Tool call sequence detection ==="
setup_project
cp "$FIXTURES/mock-session-v2a.jsonl" .harnesskit/current-session.jsonl
bash "$HOOK" 2>/dev/null
LOG=$(ls .harnesskit/session-logs/*.json | head -1)

# Should detect the Bash→Edit repeated pair (by tool name, ignoring summary)
SEQ_COUNT=$(jq '.toolCallSequences | length' "$LOG" 2>/dev/null || echo "0")
check "Has toolCallSequences (>0)" "$(jq -n --argjson v "$SEQ_COUNT" '$v > 0')" "true"

# Check that a sequence involving Bash→Edit was detected
HAS_BASH_EDIT=$(jq '[.toolCallSequences[].sequence[] | select(. == "Bash" or . == "Edit")] | length > 0' "$LOG" 2>/dev/null || echo "false")
check "Sequence involves Bash/Edit pattern" "$HAS_BASH_EDIT" "true"

# The Bash→Edit pair appears 2+ times
FIRST_SEQ_COUNT=$(jq '.toolCallSequences[0].count' "$LOG" 2>/dev/null || echo "0")
check "Sequence count >= 2" "$(jq -n --argjson v "$FIRST_SEQ_COUNT" '$v >= 2')" "true"
cleanup

# === Test: v2a JSONL produces taskTimeDistribution ===
echo ""
echo "=== v2a: Task time distribution ==="
setup_project
cp "$FIXTURES/mock-session-v2a.jsonl" .harnesskit/current-session.jsonl
bash "$HOOK" 2>/dev/null
LOG=$(ls .harnesskit/session-logs/*.json | head -1)

HAS_DIST=$(jq 'has("taskTimeDistribution")' "$LOG" 2>/dev/null || echo "false")
check "Has taskTimeDistribution" "$HAS_DIST" "true"

# 9 tool_call events: Bash(3 tsc + 1 test=4) + Edit(2) + Write(1) + WebSearch(2)
# tsc is classified as coding (not debugging). test/lint → debugging.
# coding = Bash:tsc(3) + Edit(2) + Write(1) + Bash:other(0) = 6. But wait, Bash without test/lint keywords = coding.
# Actually: Bash:tsc(3) = coding, Bash:npm test(1) = debugging, Edit(2) = coding, Write(1) = coding, WebSearch(2) = research
# coding = 6/9, debugging = 1/9, research = 2/9

CODING=$(jq '.taskTimeDistribution.coding // 0' "$LOG" 2>/dev/null || echo "0")
check "Coding ratio > 0" "$(jq -n --argjson v "$CODING" '$v > 0')" "true"

RESEARCH=$(jq '.taskTimeDistribution.research // 0' "$LOG" 2>/dev/null || echo "0")
check "Research ratio > 0" "$(jq -n --argjson v "$RESEARCH" '$v > 0')" "true"

# Sum should be 1.0
SUM=$(jq '[.taskTimeDistribution[]] | add' "$LOG" 2>/dev/null || echo "0")
check "Distribution sums to 1" "$(jq -n --argjson v "$SUM" '$v == 1')" "true"
cleanup

# === Test: v2a JSONL produces pluginUsage ===
echo ""
echo "=== v2a: Plugin usage extraction ==="
setup_project
cp "$FIXTURES/mock-session-v2a.jsonl" .harnesskit/current-session.jsonl
bash "$HOOK" 2>/dev/null
LOG=$(ls .harnesskit/session-logs/*.json | head -1)

REVIEW_INV=$(jq '.pluginUsage.review.invocations // 0' "$LOG" 2>/dev/null || echo "0")
check "Review plugin invocations = 1" "$REVIEW_INV" "1"

REVIEW_THEMES=$(jq '.pluginUsage.review.feedbackThemes | length' "$LOG" 2>/dev/null || echo "0")
check "Review has 2 feedback themes" "$REVIEW_THEMES" "2"

SIMPLIFY_INV=$(jq '.pluginUsage.simplify.invocations // 0' "$LOG" 2>/dev/null || echo "0")
check "Simplify plugin invocations = 1" "$SIMPLIFY_INV" "1"
cleanup

# === Test: v1 backward compatibility ===
echo ""
echo "=== v2a: Backward compatibility (v1 JSONL) ==="
setup_project
cp "$FIXTURES/mock-session-v2a-empty.jsonl" .harnesskit/current-session.jsonl
bash "$HOOK" 2>/dev/null
LOG=$(ls .harnesskit/session-logs/*.json | head -1)

SEQ_EMPTY=$(jq '.toolCallSequences | length' "$LOG" 2>/dev/null || echo "0")
check "No sequences from v1 data" "$SEQ_EMPTY" "0"

DIST_EMPTY=$(jq '.taskTimeDistribution | keys | length' "$LOG" 2>/dev/null || echo "0")
check "Empty distribution from v1 data" "$DIST_EMPTY" "0"

PLUGIN_EMPTY=$(jq '.pluginUsage | keys | length' "$LOG" 2>/dev/null || echo "0")
check "No plugin usage from v1 data" "$PLUGIN_EMPTY" "0"

# v1 fields still work
ERR_COUNT=$(jq '.errors | length' "$LOG" 2>/dev/null || echo "0")
check "v1 errors still captured" "$ERR_COUNT" "1"
cleanup

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
chmod +x harnesskit/tests/test-session-end-v2a.sh
bash harnesskit/tests/test-session-end-v2a.sh
```

Expected: FAIL — session-end.sh doesn't produce v2a fields yet.

- [ ] **Step 3: Implement v2a extraction in session-end.sh**

**Insert** the following block after the existing `FEATURES_FAILED` parsing (line 40), **before** `rm -f .harnesskit/current-session.jsonl` (line 42). The v2a extraction reads the same JSONL file before it gets deleted:

```bash
# --- v2a: Extract tool call data ---
TOOL_CALL_SEQUENCES="[]"
TASK_TIME_DISTRIBUTION="{}"
PLUGIN_USAGE="{}"

if [ -f ".harnesskit/current-session.jsonl" ]; then
  TOOL_LINES=$(grep '"type":"tool_call"' .harnesskit/current-session.jsonl 2>/dev/null || true)
  PLUGIN_LINES=$(grep '"type":"plugin_invocation"' .harnesskit/current-session.jsonl 2>/dev/null || true)

  # --- Tool call sequence detection (by tool name only, ignoring summary) ---
  if [ -n "$TOOL_LINES" ]; then
    TOOL_CALL_SEQUENCES=$(echo "$TOOL_LINES" | jq -s '
      [.[] | .tool] as $tools |
      # Find repeated consecutive pairs by tool name
      (reduce range(0; ($tools | length) - 1) as $i (
        {};
        ($tools[$i] + " → " + $tools[$i+1]) as $pair |
        .[$pair] = ((.[$pair] // 0) + 1)
      )) as $pairs |
      [$pairs | to_entries[] | select(.value >= 2) |
        (.key | split(" → ")) as $seq |
        {sequence: $seq, count: .value, context: "repeated pattern"}
      ]
    ' 2>/dev/null || echo "[]")

    # --- Task time distribution ---
    # Classification: Edit/Write/Bash(general) = coding, Bash(test/lint keywords) = debugging, WebSearch/WebFetch = research
    TASK_TIME_DISTRIBUTION=$(echo "$TOOL_LINES" | jq -s '
      (length) as $total |
      if $total == 0 then {} else
        (map(
          if .tool == "WebSearch" or .tool == "WebFetch" then "research"
          elif .tool == "Edit" or .tool == "Write" then "coding"
          elif (.tool == "Bash" and ((.summary // "") | test("test|jest|vitest|pytest|lint|eslint|ruff"; "i"))) then "debugging"
          elif .tool == "Bash" then "coding"
          else "other"
          end
        ) | group_by(.) | map({(.[0]): (length / $total)}) | add) // {}
      end
    ' 2>/dev/null || echo "{}")
  fi

  # --- Plugin usage extraction ---
  if [ -n "$PLUGIN_LINES" ]; then
    PLUGIN_USAGE=$(echo "$PLUGIN_LINES" | jq -s '
      group_by(.plugin) |
      map({
        (.[0].plugin): {
          invocations: length,
          feedbackThemes: [.[].feedback[] | select(. != null and . != "")] | unique
        }
      }) | add // {}
    ' 2>/dev/null || echo "{}")
  fi
fi
```

Then **REPLACE** the existing `jq -n` session log block (lines 47-65 of the current file) with the following expanded version that includes v2a fields:

```bash
jq -n \
  --arg sid "$SESSION_ID" \
  --arg start "$STARTED_AT" \
  --arg end "$ENDED_AT" \
  --arg feat "$CURRENT_FEATURE" \
  --argjson files "$FILES_CHANGED" \
  --argjson done "$FEATURES_COMPLETED" \
  --argjson failed "$FEATURES_FAILED" \
  --argjson errs "$ERRORS" \
  --argjson seqs "$TOOL_CALL_SEQUENCES" \
  --argjson dist "$TASK_TIME_DISTRIBUTION" \
  --argjson plugins "$PLUGIN_USAGE" \
  '{
    sessionId: $sid,
    startedAt: $start,
    endedAt: $end,
    currentFeature: $feat,
    filesChanged: $files,
    featuresCompleted: $done,
    featuresFailed: $failed,
    errors: $errs,
    toolCallSequences: $seqs,
    taskTimeDistribution: $dist,
    pluginUsage: $plugins
  }' > ".harnesskit/session-logs/$SESSION_ID.json"
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bash harnesskit/tests/test-session-end-v2a.sh
```

Expected: All tests PASS.

- [ ] **Step 5: Run existing v1 tests to verify no regression**

```bash
bash harnesskit/tests/test-session-end.sh
```

Expected: All 5 v1 tests still PASS.

- [ ] **Step 6: Commit**

```bash
git add harnesskit/hooks/session-end.sh harnesskit/tests/test-session-end-v2a.sh
git commit -m "feat(v2a): add tool call sequence, time distribution, plugin usage extraction to session-end.sh"
```

---

### Task 4: init.md — v2a Config Schema

**Files:**
- Modify: `harnesskit/skills/init.md`

- [ ] **Step 1: Read current init.md**

Current init.md generates config.json with v1 fields. Need to add v2a initialization.

- [ ] **Step 2: Add v2a config initialization**

In `harnesskit/skills/init.md`, update the Harness Infrastructure section. After step 6 (insights-history.json), add:

```markdown
7. **v2a fields in .harnesskit/config.json** — if `schemaVersion` is missing or < "2.0", add:
   - `schemaVersion`: `"2.0"`
   - `uncoveredAreas`: populated during marketplace plugin discovery (areas with no matching plugin)
   - `reviewInternalization`: `{"stage": "marketplace_only", "supplementSince": null, "coveragePercent": null}`
   - `customHooks`: `[]`
   - `customSkills`: `[]`
   - `customAgents`: `[]`
   - `removedPlugins`: `[]`
```

- [ ] **Step 3: Commit**

```bash
git add harnesskit/skills/init.md
git commit -m "feat(v2a): add v2a config schema initialization to init.md"
```

---

### Task 4b: Migration Detection — v1 → v2a

**Files:**
- Modify: `harnesskit/skills/init.md`
- Modify: `harnesskit/hooks/session-start.sh` (optional nudge)

- [ ] **Step 1: Add migration mode to init.md**

In `harnesskit/skills/init.md`, add a section after the v2a config initialization:

```markdown
### Migration from v1

If `.harnesskit/config.json` exists but has no `schemaVersion` or `schemaVersion < "2.0"`:
1. This is a v1 project upgrading to v2a
2. Do NOT re-run full setup — preserve all existing data
3. Add missing v2a fields to existing config.json (non-destructive merge):
   - Add `schemaVersion: "2.0"`
   - Add `uncoveredAreas: []` (will be populated by next insights run)
   - Add `reviewInternalization: {"stage": "marketplace_only", ...}`
   - Add `customHooks: []`, `customSkills: []`, `customAgents: []`
   - Add `removedPlugins: []`
4. Update `templates/claude-md/base.md` references in project CLAUDE.md (append v2a logging rules)
5. Output: "✅ Migrated to v2a schema. Existing data preserved."
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/init.md
git commit -m "feat(v2a): add v1→v2a migration path to init.md"
```

---

### Task 5: status.md — v2a Dashboard Fields

**Files:**
- Modify: `harnesskit/skills/status.md`

- [ ] **Step 1: Read current status.md**

Current dashboard shows: preset, project type, features, toolkit (skills/agents/hooks), failures, last insights.

- [ ] **Step 2: Add v2a fields to dashboard**

Update the output format in `harnesskit/skills/status.md`:

```markdown
Output format:

\```
═══ HarnessKit Status ═══

⚙️  Preset: {preset} (since {detectedAt})
    Schema: v{schemaVersion}
📂  Project: {framework} + {language} + {testFramework}

📋  Features:
    {progress bar} {done}/{total} ({percentage}%)

🛠  Toolkit:
    Marketplace Plugins: {list from config.json installedPlugins}
    Custom Skills: {list from config.json customSkills, or "none yet"}
    Custom Agents: {list from config.json customAgents, or "none yet"}
    Custom Hooks: {list from config.json customHooks, or "none yet"}
    Dev Hooks: {list active hooks from .claude/settings.json}

🔍  Review Internalization: {stage} {coveragePercent if supplement/replace}
    Uncovered Areas: {list from config.json uncoveredAreas, or "all covered"}

⚠️  Active Failures: {count}
    {list top 3 open failures with pattern and occurrences}

💡  Last Insights: {date or "never"}

══════════════════════════
\```
```

Also update the Instructions section to read the new config fields:

```markdown
## Instructions

1. Read `.harnesskit/config.json` for preset, schemaVersion, installedPlugins, uncoveredAreas, reviewInternalization, customSkills, customAgents, customHooks
2. Read `.harnesskit/detected.json` for project type
3. Read `docs/feature_list.json` for feature progress
4. Read `.harnesskit/failures.json` for active failures
5. Read `.harnesskit/insights-history.json` for last insights date
```

- [ ] **Step 3: Commit**

```bash
git add harnesskit/skills/status.md
git commit -m "feat(v2a): add review internalization, custom toolkit, uncovered areas to status dashboard"
```

---

### Task 6: insights.md — v2a Analysis Dimensions and Proposal Types

**Files:**
- Modify: `harnesskit/skills/insights.md`

This is the largest change. The insights skill gains 3 new analysis dimensions and 4 new proposal types.

- [ ] **Step 1: Read current insights.md**

Current structure: Data Collection → Analysis Dimensions (5) → Report Output → Proposal Generation → Proposal Rules → After Report → Save proposals.

- [ ] **Step 2: Add new data sources to Data Collection**

After item 9 (`.claude/settings.json`), add:

```markdown
10. `.harnesskit/config.json` — v2a fields: `installedPlugins`, `uncoveredAreas`, `reviewInternalization`, `customSkills`, `customAgents`, `customHooks`
```

- [ ] **Step 3: Add 3 new analysis dimensions**

After existing dimension 5 (Preset Fit), add:

```markdown
### 6. Time-Sink Patterns (v2a)
- Analyze `taskTimeDistribution` across sessions
- Flag task types consuming >30% of session time in 3+ sessions (scaled by preset)
- Cross-reference with installed plugins and custom agents — is there already a tool for this?
- If no tool exists → `agent_creation` proposal

### 7. Repeated Manual Actions (v2a)
- Analyze `toolCallSequences` across sessions
- Flag sequences appearing in 3+ sessions (scaled by preset)
- Cross-reference with existing hooks — is this already automated?
- If not automated → `hook_creation` proposal

### 8. Plugin Coverage Gap (v2a)
- Compare `installedPlugins` effectiveness against error patterns
- Check `uncoveredAreas` — do errors cluster in uncovered areas?
- If installed plugin covers area but errors persist → `skill_customization` proposal
- If no plugin covers the area → `skill_creation` or `plugin_recommendation` proposal
```

- [ ] **Step 3b: Add feedbackThemes normalization note**

Add to the Plugin Coverage Gap dimension or as a standalone note:

```markdown
### Feedback Theme Normalization (v2a)
Before analyzing `pluginUsage.feedbackThemes` across sessions:
1. Normalize slugs: lowercase, hyphens, no special chars
2. Merge semantically similar slugs (e.g., "missing-error-boundary" ≈ "no-error-boundary")
3. Reference existing themes from prior session-logs to maintain consistency
This normalization happens at insights analysis time (Claude-powered, semantic matching).
```

- [ ] **Step 4: Enrich existing Toolkit Usage dimension**

Update dimension 4 (Toolkit Usage):

```markdown
### 4. Toolkit Usage
- Which installed marketplace plugins are referenced in sessions?
- Track plugin effectiveness: do errors in plugin-covered areas decrease over time?
- If installed plugin is not reducing errors → propose customization via `/skill-builder`
- Are there usage patterns that no installed plugin covers? → propose custom skill or marketplace recommendation
- Are custom skills/agents/hooks being used? Are they effective?
- Are dev hooks being bypassed or causing friction?
```

- [ ] **Step 5: Add new proposal types to Proposal Generation**

After existing proposal types, add:

```markdown
### v2a Proposal Types

#### `agent_creation`
- **Trigger**: Same task type >30% time in 3+ sessions (preset-scaled)
- **Minimum sessions**: 5 (intermediate), 3 (beginner), 8 (advanced)
- **Cooldown key**: `agent_creation:{task-type-slug}`
- **Cooldown**: 15 sessions after rejection
- **Diff format**: Show proposed agent.md content
- **Execution**: `/skill-builder` generates agent with session data context
- **Target**: `.harnesskit/agents/{name}.md`

#### `hook_creation`
- **Trigger**: Same tool call sequence (3+ steps) in 3+ sessions (preset-scaled)
- **Minimum sessions**: 5 (intermediate), 3 (beginner), 8 (advanced)
- **Cooldown key**: `hook_creation:{sequence-summary-slug}`
- **Cooldown**: 10 sessions after rejection
- **Diff format**: Show proposed shell script + hook registration point + rationale
- **Hook point decision**: "pre-execution check" → PreToolUse, "post-execution action" → PostToolUse
- **Conflict check**: If same-purpose hook exists → propose replace/coexist choice
- **Execution**: Generate shell script directly (not via /skill-builder)
- **Target**: `.harnesskit/hooks/{name}.sh` + `.claude/settings.json`

#### `review_supplement`
- **Trigger**: Same review feedback theme in 5+ sessions
- **Minimum sessions**: 5 (intermediate), 3 (beginner), 8 (advanced)
- **Prerequisite**: `/review` or similar marketplace plugin installed
- **Cooldown key**: `review_supplement`
- **Cooldown**: 15 sessions after rejection
- **Diff format**: Show proposed review rules content
- **Execution**: `/skill-builder` generates review skill with feedback data context
- **Target**: `.harnesskit/skills/project-review-rules.md`
- **Side effect**: Update `config.json` reviewInternalization to `stage: "supplement"`

#### `review_replace`
- **Trigger**: Supplement skill covers 80%+ of themes + 10+ sessions active
- **Prerequisite**: `review_supplement` accepted and active
- **Cooldown key**: `review_replace`
- **Cooldown**: 20 sessions after rejection
- **Coverage measurement**: (themes covered by supplement) / (total unique themes in last 10 sessions) × 100
- **Diff format**: Show merged review skill content + marketplace plugin removal
- **Execution**: `/skill-builder` merges supplement into full review skill
- **Target**: `.harnesskit/skills/code-review.md`
- **Side effect**: Remove marketplace plugin, record in `config.json` removedPlugins, update reviewInternalization to `stage: "replace"`
- **Rollback**: If new errors increase 50%+ in 5 sessions post-replace → auto-propose marketplace reinstall
```

- [ ] **Step 6: Update plugin_recommendation to be data-driven**

Replace existing plugin_recommendation description:

```markdown
#### `plugin_recommendation` (v2a enhanced)
- **v1 behavior**: Static rules from detected.json (setup-time only)
- **v2a behavior**: Data-driven from session-logs (every insights run)
- **Trigger**: Usage pattern matches known plugin category in 3+ sessions
- **Examples**:
  - "Code review requested 8 times in 5 sessions, no review plugin installed" → recommend `/review`
  - "Security checks run manually before deploy" → recommend `/security-review`
- **Minimum sessions**: 3 (all presets)
- **Cooldown key**: `plugin_recommendation:{plugin-name}`
- **Cooldown**: 10 sessions after rejection
```

- [ ] **Step 7: Add threshold configuration section**

Add after Proposal Rules:

```markdown
### Threshold Configuration (v2a)

All thresholds scale by preset:

| Threshold | Beginner | Intermediate | Advanced |
|-----------|----------|-------------|----------|
| Minimum sessions for generation proposals | 3 | 5 | 8 |
| Pattern repetition (sessions) | 2 | 3 | 5 |
| Agent time-sink % | 25% | 30% | 40% |
| Review replace wait (sessions after supplement) | 8 | 10 | 15 |

### Priority Ordering (v2a)

When >5 proposals qualify, select by priority:

1. `skill_customization` / `skill_creation` (error reduction)
2. `hook_creation` (time savings)
3. `review_supplement` / `review_replace` (quality)
4. `agent_creation` (productivity)
5. `plugin_recommendation` (ecosystem)

Same-priority tiebreak: more sessions affected → higher error/repetition count.

### Cooldown Keys (v2a)

Rejection cooldown applies to type + target combination:
- `skill_customization:{plugin-name}`, `agent_creation:{task-type}`, `hook_creation:{sequence-slug}`, etc.
- Different targets of the same type are independent (rejecting one doesn't block others)
```

- [ ] **Step 8: Commit**

```bash
git add harnesskit/skills/insights.md
git commit -m "feat(v2a): add time-sink, repeated actions, coverage gap analysis + 4 new proposal types to insights"
```

---

### Task 7: apply.md — v2a Execution Paths

**Files:**
- Modify: `harnesskit/skills/apply.md`

- [ ] **Step 1: Read current apply.md**

Current: reads pending-proposals.json → presents each → y/n/edit → applies based on type → updates insights-history.json.

- [ ] **Step 2: Add v2a execution paths**

In the "Process user response" section, add after existing execution paths:

```markdown
   - **y (yes)**: Apply the change
     - For skill customization (type=skill_customization): invoke `/skill-builder` to fork/customize the installed marketplace plugin with project-specific rules
     - For skill creation (type=skill_creation): invoke `/skill-builder` with usage data context — only when no marketplace plugin covers the gap
     - For file edits (CLAUDE.md, .claudeignore, config.json, etc.): apply directly using Edit tool
     - For plugin recommendations (type=plugin_recommendation): run marketplace install command
     - For agent creation (type=agent_creation):
       1. Invoke `/skill-builder` with: detected.json + session-logs excerpts showing time-sink pattern + task descriptions
       2. Save generated agent.md to `.harnesskit/agents/{name}.md`
       3. Update `config.json` customAgents array: `{"name": "{name}", "file": ".harnesskit/agents/{name}.md", "createdAt": "{date}", "sourceProposal": "{id}", "type": "agent_creation"}`
     - For hook creation (type=hook_creation):
       1. Save proposed shell script to `.harnesskit/hooks/{name}.sh`
       2. `chmod +x` the script
       3. Check `.claude/settings.json` for conflicting hooks at the same hook point with same purpose → if found, ask user to replace or coexist
       4. Append hook to `.claude/settings.json` at the specified hook point (end of array)
       5. Update `config.json` customHooks array: `{"name": "{name}", "file": ".harnesskit/hooks/{name}.sh", "hookPoint": "{point}", "createdAt": "{date}", "sourceProposal": "{id}"}`
     - For review supplement (type=review_supplement):
       1. Invoke `/skill-builder` with: review feedback themes + CLAUDE.md conventions + detected.json
       2. Save generated skill to `.harnesskit/skills/project-review-rules.md`
       3. Add reference to CLAUDE.md
       4. Update `config.json`: reviewInternalization.stage = "supplement", supplementSince = "{date}"
       5. Update `config.json` customSkills array
     - For review replace (type=review_replace):
       1. Confirm with user: "This will remove marketplace /review plugin. Continue?"
       2. Invoke `/skill-builder` to merge supplement + expanded rules into full review skill
       3. Save to `.harnesskit/skills/code-review.md`
       4. Run marketplace uninstall for review plugin
       5. Update `config.json`: reviewInternalization.stage = "replace", record in removedPlugins with version info
       6. Update CLAUDE.md references
```

- [ ] **Step 3: Commit**

```bash
git add harnesskit/skills/apply.md
git commit -m "feat(v2a): add agent_creation, hook_creation, review_supplement, review_replace execution paths to apply"
```

---

### Task 8: Run All Tests + End-to-End Verification

**Files:**
- All test files

- [ ] **Step 1: Run all v1 tests**

```bash
for t in harnesskit/tests/test-*.sh; do echo "--- $t ---"; bash "$t" 2>&1 | tail -2; echo ""; done
```

Expected: All v1 tests pass (73 from 7 suites) + v2a tests pass (new suite).

- [ ] **Step 2: Verify v2a session-end integration**

Create a temp project, run session-end with v2a fixture, verify log contains all new fields:

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.harnesskit/session-logs"
echo '{"preset":"intermediate","schemaVersion":"2.0","installedPlugins":[],"uncoveredAreas":[],"reviewInternalization":{"stage":"marketplace_only"},"customHooks":[],"customSkills":[],"customAgents":[],"removedPlugins":[]}' > "$TMPDIR/.harnesskit/config.json"
echo '{"failures":[]}' > "$TMPDIR/.harnesskit/failures.json"
echo "2026-03-20T14:00:00Z" > "$TMPDIR/.harnesskit/session-start-time.txt"
cp harnesskit/tests/fixtures/mock-session-v2a.jsonl "$TMPDIR/.harnesskit/current-session.jsonl"
cd "$TMPDIR" && git init -q && git commit --allow-empty -m "init" -q
bash "$(cd - > /dev/null && pwd)/harnesskit/hooks/session-end.sh" 2>/dev/null
LOG=$(ls .harnesskit/session-logs/*.json | head -1)
echo "Session log fields:"
jq 'keys' "$LOG"
echo ""
echo "toolCallSequences:"
jq '.toolCallSequences' "$LOG"
echo ""
echo "taskTimeDistribution:"
jq '.taskTimeDistribution' "$LOG"
echo ""
echo "pluginUsage:"
jq '.pluginUsage' "$LOG"
cd -
rm -rf "$TMPDIR"
```

Expected: All 3 v2a fields present and populated correctly.

- [ ] **Step 3: Verify skill files are syntactically valid**

```bash
for f in harnesskit/skills/*.md; do
  if head -1 "$f" | grep -q "^---"; then
    echo "✅ $f has frontmatter"
  else
    echo "❌ $f missing frontmatter"
  fi
done
```

- [ ] **Step 4: Verify no uncommitted changes remain**

```bash
git status
```

If there are uncommitted changes, stage specific files and commit:

```bash
git add harnesskit/skills/*.md harnesskit/hooks/*.sh harnesskit/templates/claude-md/base.md harnesskit/tests/
git commit -m "feat(v2a): complete v2a implementation — intelligent harness evolution"
```

---

## Summary

After completing this plan, you have:
- ✅ base.md updated with v2a event logging protocol (tool_call, plugin_invocation)
- ✅ session-end.sh extracts toolCallSequences, taskTimeDistribution, pluginUsage from JSONL
- ✅ insights.md has 8 analysis dimensions (5 v1 + 3 v2a) and 4 new proposal types
- ✅ apply.md has execution paths for agent_creation, hook_creation, review_supplement, review_replace
- ✅ status.md shows review internalization, custom toolkit, uncovered areas
- ✅ init.md initializes v2a config schema fields
- ✅ All v1 tests still pass (73 tests, backward compatible)
- ✅ New v2a tests pass (tool call sequences, time distribution, plugin usage, v1 compat)

**Next:** v2b plan for extended features (A/B testing, PRD decomposition, worktree isolation, bible guideline)
