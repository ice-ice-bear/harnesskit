---
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
10. `.harnesskit/config.json` — v2a fields: `installedPlugins`, `uncoveredAreas`, `reviewInternalization`, `customSkills`, `customAgents`, `customHooks`

## Analysis Dimensions

### 1. Error Patterns
- Which error patterns repeat across sessions?
- Are there open failures without rootCause?
- For failures with rootCause: is the prevention rule reflected in CLAUDE.md or a skill?

### 2. Feature Progress
- Sessions per feature (velocity)
- Feature failure rate
- Are features too large? (multiple sessions without completion)
- Feature switching detection: if `current-feature.txt` changed multiple times in a session (visible in session-logs), suggest worktree isolation
  → "feat-003과 feat-005 사이를 {N}회 전환했습니다. /harnesskit:worktree를 사용하여 격리 작업을 고려해보세요."
  ※ This is a nudge in the report output, not a separate proposal type

### 3. Guardrail Activity
- BLOCK/WARN frequency from session logs
- Are guardrails too strict or too lenient?

### 4. Toolkit Usage
- Which installed marketplace plugins are referenced in sessions?
- Track plugin effectiveness: do errors in plugin-covered areas decrease over time?
- If installed plugin is not reducing errors → propose customization via `/skill-builder`
- Are there usage patterns that no installed plugin covers? → propose custom skill or marketplace recommendation
- Are custom skills/agents/hooks being used? Are they effective?
- Are dev hooks being bypassed or causing friction?

### 5. Preset Fit
Apply quantified thresholds:
- **Upgrade**: 0 BLOCKs in 10 sessions AND avg features > 1/session AND 0 repeated errors
- **Downgrade**: same error in 3/5 sessions OR failure rate > 50% OR avg WARNs >= 3/session

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

### Feedback Theme Normalization (v2a)
Before analyzing `pluginUsage.feedbackThemes` across sessions:
1. Normalize slugs: lowercase, hyphens, no special chars
2. Merge semantically similar slugs (e.g., "missing-error-boundary" ≈ "no-error-boundary")
3. Reference existing themes from prior session-logs to maintain consistency
This normalization happens at insights analysis time (Claude-powered, semantic matching).

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

**Data source for recommendations:**
1. Read `${CLAUDE_PLUGIN_ROOT}/templates/marketplace-recommendations.json`
2. Cross-reference with `config.json` `installedPlugins` — only recommend uninstalled plugins
3. Match session usage patterns against recommendation conditions
4. Provide exact install command: `/plugin install {name}@claude-plugins-official`

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

### Bible Citation (v2b)

When generating proposal reasons, reference `.harnesskit/bible.md` principles where applicable:
- Read `.harnesskit/bible.md` if it exists
- When a proposal aligns with a bible principle, cite it in the Reason field:
  "바이블 원칙 '{section}: {principle}'에 따라, {recommendation}"
- Bible citation is optional context — proposals are valid without it
- Bible is reference only, not a directive source

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
