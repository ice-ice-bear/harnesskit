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
- Are guardrails too strict or too lenient?

### 4. Toolkit Usage
- Which installed marketplace plugins are referenced in sessions?
- Are there usage patterns that no installed plugin covers? → propose custom skill via `/skill-builder`
- Are installed plugins insufficient for project-specific needs? → propose customization via `/skill-builder`
- Are dev hooks being bypassed or causing friction?

### 5. Preset Fit
Apply quantified thresholds:
- **Upgrade**: 0 BLOCKs in 10 sessions AND avg features > 1/session AND 0 repeated errors
- **Downgrade**: same error in 3/5 sessions OR failure rate > 50% OR avg WARNs >= 3/session

## Report Output

```
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
```

## Proposal Generation

For each issue found, generate a concrete proposal:

```
🔧 Proposal [N/{total}]: {summary}
Target: {file path}
Type: {rule_addition | pattern_addition | skill_customization | skill_creation | hook_adjustment | preset_change | plugin_recommendation}

--- {file} (current)
+++ {file} (proposed)
@@ ... @@
- existing line
+ proposed new line

Reason: {why this change helps, based on data}
```

### Proposal Rules

1. Check `insights-history.json` — skip if same category + target was rejected within last 10 sessions
2. For skill customization: propose forking an installed marketplace plugin with project-specific rules via `/skill-builder`
3. For skill creation: only when no marketplace plugin covers the gap — create via `/skill-builder` based on usage data
4. For plugin recommendations: provide the marketplace install command
5. For preset changes: show before/after comparison
6. Maximum 5 proposals per insights run (prioritize by impact)

## After Report

Tell the user: "Run /harnesskit:apply to review and apply these proposals."

Save proposals to `.harnesskit/pending-proposals.json`:
```json
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
```
