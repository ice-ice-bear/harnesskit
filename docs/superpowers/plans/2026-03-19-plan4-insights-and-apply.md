# Plan 4: Insights + Apply System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `/harnesskit:insights` analysis + report + proposal system and `/harnesskit:apply` approval workflow, completing the observe→improve loop.

**Architecture:** `insights.md` skill reads accumulated session data and uses Claude to analyze patterns, generate a report, and propose concrete file changes as diffs. `apply.md` skill presents each proposal for y/n approval and applies accepted changes. `status.md` provides a quick read-only dashboard. All proposals are tracked in `insights-history.json` to prevent re-proposal of rejected items.

**Tech Stack:** Claude Code Plugin skills (Markdown), JSON

**Spec:** `docs/superpowers/specs/2026-03-19-harnesskit-design.md` — Sections 6, 8

**Depends on:** Plan 1 (config), Plan 2 (generated files), Plan 3 (session-logs, failures.json)

---

## File Structure

```
harnesskit/
├── skills/
│   ├── insights.md                      # /harnesskit:insights — analysis + proposals
│   ├── apply.md                         # /harnesskit:apply — approval + execution
│   └── status.md                        # /harnesskit:status — quick dashboard
└── plugin.json                          # Updated with insights, apply, status skills
```

---

### Task 1: Status Skill

**Files:**
- Create: `harnesskit/skills/status.md`

- [ ] **Step 1: Write status.md**

```markdown
---
name: status
description: Show current HarnessKit harness status — preset, feature progress, active failures, installed toolkit
user_invocable: true
---

# /harnesskit:status

Display a quick dashboard of the current harness state. Read files only, no modifications.

## Instructions

1. Read `.harnesskit/config.json` for preset and detection date
2. Read `.harnesskit/detected.json` for project type
3. Read `docs/feature_list.json` for feature progress
4. Read `.harnesskit/failures.json` for active failures
5. Read `.harnesskit/insights-history.json` for last insights date
6. List `.harnesskit/skills/` for installed skills
7. List `.harnesskit/agents/` for installed agents

Output format:

\`\`\`
═══ HarnessKit Status ═══

⚙️  Preset: {preset} (since {detectedAt})
📂  Project: {framework} + {language} + {testFramework}

📋  Features:
    {progress bar} {done}/{total} ({percentage}%)

🛠  Toolkit:
    Skills: {list of .harnesskit/skills/*.md names}
    Agents: {list of .harnesskit/agents/*.md names}
    Dev Hooks: {list active hooks from .claude/settings.json}

⚠️  Active Failures: {count}
    {list top 3 open failures with pattern and occurrences}

💡  Last Insights: {date or "never"}

══════════════════════════
\`\`\`

If `.harnesskit/config.json` does not exist, output:
\`\`\`
HarnessKit is not initialized. Run /harnesskit:setup first.
\`\`\`
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/status.md
git commit -m "feat: add /harnesskit:status skill — quick dashboard"
```

---

### Task 2: Insights Skill

**Files:**
- Create: `harnesskit/skills/insights.md`

- [ ] **Step 1: Write insights.md**

```markdown
---
name: insights
description: Analyze session logs, failures, and usage patterns to propose harness and toolkit improvements as concrete diffs
user_invocable: true
---

# /harnesskit:insights

Analyze accumulated session data and propose concrete improvements to the harness and toolkit.

## Data Collection

Read the following files (skip gracefully if missing):

1. `.harnesskit/session-logs/*.json` — last 10 session logs (sorted by date)
2. `.harnesskit/failures.json` — all open failures
3. `.harnesskit/config.json` — current preset and settings
4. `.harnesskit/detected.json` — project properties
5. `.harnesskit/insights-history.json` — previous proposals (to avoid re-suggesting rejected ones)
6. `docs/feature_list.json` — feature progress
7. `CLAUDE.md` — current rules
8. `.harnesskit/skills/*.md` — current skills (read file list and contents)
9. `.claude/settings.json` — current hooks configuration

## Analysis Dimensions

Analyze across these dimensions:

### 1. Error Patterns
- Which error patterns repeat across sessions?
- Are there open failures without rootCause?
- For failures with rootCause: is the prevention rule reflected in CLAUDE.md or a skill?

### 2. Feature Progress
- Sessions per feature (velocity)
- Feature failure rate
- Are features too large? (multiple sessions without completion)

### 3. Guardrail Activity
- BLOCK/WARN frequency from session logs
- Are guardrails too strict (many overrides) or too lenient?

### 4. Toolkit Usage
- Which skills are referenced in sessions?
- Are there patterns that should be a skill but aren't?
- Are dev hooks being bypassed or causing friction?

### 5. Preset Fit
Apply quantified thresholds from spec Section 6.5:
- **Upgrade**: 0 BLOCKs in 10 sessions AND avg features > 1/session AND 0 repeated errors
- **Downgrade**: same error in 3/5 sessions OR failure rate > 50% OR avg WARNs >= 3/session

## Report Output

Output a structured report:

\`\`\`
═══ HarnessKit Insights Report ═══

📊 Session Statistics (last N sessions)
  ├ Features completed: X/Y (Z%)
  ├ Avg per session: N
  └ Errors per session: avg N

🔴 Repeated Problems (Top 3)
  1. "{pattern}" — {N} sessions ({files})
     → Root cause: {analysis or "not yet analyzed"}
  2. ...

📈 Preset Fit
  Current: {preset}
  Analysis: {assessment}
  → {recommendation or "current preset is appropriate"}

🔧 Improvement Proposals ({count})
  [1] {target file}: {summary}
  [2] {target file}: {summary}
  ...

══════════════════════════════════
\`\`\`

## Proposal Generation

For each issue found, generate a concrete proposal:

\`\`\`
🔧 Proposal [N/{total}]: {summary}
Target: {file path}
Type: {rule_addition | pattern_addition | skill_improvement | hook_adjustment | preset_change | plugin_recommendation | agent_recommendation}

--- {file} (current)
+++ {file} (proposed)
@@ ... @@
- existing line
+ proposed new line

Reason: {why this change helps, based on data}
\`\`\`

### Proposal Rules

1. Check `insights-history.json` before proposing — skip if same category + target was rejected within last 10 sessions
2. For skill improvements: note that `/harnesskit:apply` will use `/skill-builder` for execution
3. For marketplace recommendations: provide the install command
4. For preset changes: show before/after comparison of what changes
5. Maximum 5 proposals per insights run (prioritize by impact)

## After Report

Tell the user:
\`\`\`
Run /harnesskit:apply to review and apply these proposals.
\`\`\`

Save proposals to `.harnesskit/pending-proposals.json`:
\`\`\`json
{
  "generatedAt": "{ISO timestamp}",
  "proposals": [
    {
      "id": "ins-001",
      "target": "CLAUDE.md",
      "type": "rule_addition",
      "summary": "Add null check rule",
      "diff": "...",
      "reason": "..."
    }
  ]
}
\`\`\`
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/insights.md
git commit -m "feat: add /harnesskit:insights skill — analysis, report, and proposal generation"
```

---

### Task 3: Apply Skill

**Files:**
- Create: `harnesskit/skills/apply.md`

- [ ] **Step 1: Write apply.md**

```markdown
---
name: apply
description: Review and apply improvement proposals from /harnesskit:insights — presents diffs for approval
user_invocable: true
---

# /harnesskit:apply

Review and apply proposals generated by `/harnesskit:insights`.

## Instructions

1. Read `.harnesskit/pending-proposals.json`
   - If not found: "No pending proposals. Run /harnesskit:insights first."

2. For each proposal, present to the user:

\`\`\`
🔧 Proposal [{N}/{total}]: {summary}
Target: {file path}
Type: {type}

{diff view}

Reason: {reason}

Apply? (y/n/edit)
\`\`\`

3. Process user response:
   - **y (yes)**: Apply the change
     - For skill improvements (type=skill_improvement or skill_creation): invoke `/skill-builder` with the proposal context
     - For file edits (CLAUDE.md, .claudeignore, config.json, etc.): apply directly using Edit tool
     - For marketplace recommendations: show install command, ask if user wants to run it
     - For agent recommendations: copy template to `.harnesskit/agents/`
   - **n (no)**: Skip, ask for optional rejection reason
   - **edit**: Let user modify the proposal, then apply modified version

4. After all proposals processed, update `.harnesskit/insights-history.json`:

\`\`\`json
{
  "history": [
    {
      "date": "{ISO date}",
      "sessionCount": {sessions analyzed},
      "proposals": [
        {
          "id": "ins-001",
          "target": "CLAUDE.md",
          "type": "rule_addition",
          "summary": "Add null check rule",
          "status": "accepted",
          "rejectedUntilSession": null
        },
        {
          "id": "ins-002",
          "target": ".claudeignore",
          "type": "pattern_addition",
          "summary": "Add coverage/ exclusion",
          "status": "rejected",
          "reason": "Already handled by .gitignore",
          "rejectedUntilSession": {current_session_count + 10}
        }
      ]
    }
  ]
}
\`\`\`

5. Delete `.harnesskit/pending-proposals.json` after processing

6. Output summary:
\`\`\`
✅ Proposals processed:
  - Accepted: {count}
  - Rejected: {count}
  - Edited: {count}

Changes applied. They will take effect in the next session.
\`\`\`
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/apply.md
git commit -m "feat: add /harnesskit:apply skill — proposal review and application"
```

---

### Task 4: Update plugin.json with All Skills

**Files:**
- Modify: `harnesskit/plugin.json`

- [ ] **Step 1: Update plugin.json**

```json
{
  "name": "harnesskit",
  "version": "0.1.0",
  "description": "Adaptive harness for vibe coders — detect, configure, observe, improve",
  "skills": [
    "skills/setup.md",
    "skills/init.md",
    "skills/insights.md",
    "skills/apply.md",
    "skills/status.md",
    "skills/test.md",
    "skills/lint.md",
    "skills/typecheck.md",
    "skills/dev.md"
  ],
  "agents": [
    "agents/orchestrator.md"
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/plugin.json
git commit -m "feat: register all skills in plugin manifest"
```

---

### Task 5: End-to-End Verification Checklist

This is a manual verification task — no code to write, but critical to confirm everything works together.

- [ ] **Step 1: Verify plugin structure**

```bash
# All required files exist
ls harnesskit/plugin.json
ls harnesskit/skills/{setup,init,insights,apply,status,test,lint,typecheck,dev}.md
ls harnesskit/agents/orchestrator.md
ls harnesskit/hooks/{session-start,session-end,guardrails,post-edit-lint,post-edit-typecheck}.sh
ls harnesskit/scripts/detect-repo.sh
ls harnesskit/templates/presets/{beginner,intermediate,advanced}.json
ls harnesskit/templates/claude-md/{base,nextjs,python-fastapi,generic}.md
ls harnesskit/templates/claudeignore/{nextjs,python,generic}.txt
ls harnesskit/templates/feature-list/starter.json
```

- [ ] **Step 2: Run all tests**

```bash
bash harnesskit/tests/test-detect-repo.sh
bash harnesskit/tests/test-guardrails.sh
bash harnesskit/tests/test-session-start.sh
bash harnesskit/tests/test-session-end.sh
bash harnesskit/tests/test-hooks-integration.sh
bash harnesskit/tests/test-setup-flow.sh
bash harnesskit/tests/test-init-templates.sh
```

Expected: All tests PASS.

- [ ] **Step 3: Validate plugin.json references**

```bash
# Every skill referenced in plugin.json must exist
jq -r '.skills[]' harnesskit/plugin.json | while read f; do
  [ -f "harnesskit/$f" ] && echo "✅ $f" || echo "❌ $f MISSING"
done

jq -r '.agents[]' harnesskit/plugin.json | while read f; do
  [ -f "harnesskit/$f" ] && echo "✅ $f" || echo "❌ $f MISSING"
done
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete HarnessKit v0.1.0 — all plans implemented"
```

---

## Summary

After completing Plan 4, you have the complete HarnessKit v0.1.0:
- ✅ `/harnesskit:status` — quick dashboard of harness state
- ✅ `/harnesskit:insights` — session data analysis + concrete improvement proposals
- ✅ `/harnesskit:apply` — proposal review + approval + execution (with /skill-builder for skills)
- ✅ Full plugin manifest with all 9 skills registered
- ✅ End-to-end verification

## Complete HarnessKit v0.1.0 Feature List

| Command | Plan | Status |
|---------|------|--------|
| `/harnesskit:setup` | Plan 1 | Detection + preset selection |
| File generation | Plan 2 | CLAUDE.md, .claudeignore, feature_list, progress, skills, hooks, agents |
| Session hooks | Plan 3 | Briefing, guardrails, log+failures+nudge |
| `/harnesskit:insights` | Plan 4 | Analysis + report + proposals |
| `/harnesskit:apply` | Plan 4 | Approval + execution |
| `/harnesskit:status` | Plan 4 | Dashboard |
| `/harnesskit:test` | Plan 2 | Test runner + failure tracking |
| `/harnesskit:lint` | Plan 2 | Linter + formatter |
| `/harnesskit:typecheck` | Plan 2 | Type checker |
| `/harnesskit:dev` | Plan 2 | Dev server |
| `/harnesskit:reset` | Plan 1 | Re-initialize |
