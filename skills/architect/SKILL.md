---
name: architect
description: Design agent teams for your domain using 6 orchestration patterns — analyzes project, selects pattern, generates agent definitions and orchestrator
user_invocable: true
---

# /harnesskit:architect

Design a complete agent team for your domain: audit existing agents, select an orchestration pattern, generate agent definitions, and register everything in CLAUDE.md.

## Usage

```
/harnesskit:architect [domain-description]
```

If no domain description is provided, infer the domain from `.harnesskit/detected.json` and session context.

## Prerequisites

- `.harnesskit/config.json` must exist (HarnessKit initialized)
- `.harnesskit/detected.json` must exist (run `/harnesskit:setup` first)

---

## Phase 1: Audit Existing Agents

Check for agents already defined in the project:

1. List files in `.claude/agents/` (if directory exists)
2. Read `.harnesskit/config.json` → `customAgents` array
3. Scan `CLAUDE.md` for any agent team sections

Present findings:

```
🔍 Existing Agents Audit

  .claude/agents/:
    - reviewer.md (code review)
    - test-writer.md (test generation)

  config.json customAgents: 1 entry
    - api-helper (type: utility)

  CLAUDE.md agent sections: none

Options:
  [A] Create new agent team from scratch
  [B] Extend existing agents with new team role(s)
  [C] Refactor existing agents under a new orchestrator

Choice (A/B/C):
```

Wait for user selection before proceeding.

---

## Phase 2: Domain Analysis

Read and analyze project context:

1. Read `.harnesskit/detected.json` — framework, language, git, testFramework, buildTool
2. Read `.harnesskit/current-session.jsonl` if available — recent tool call sequences and task types
3. Read `progress/claude-progress.txt` if available — recurring task patterns

Determine the primary domain (e.g., "Next.js API development", "data pipeline", "CLI tooling") and recommend an orchestration pattern.

Load `${CLAUDE_PLUGIN_ROOT}/templates/references/agent-design-patterns.md` to select from the 6 available patterns.

Present domain summary:

```
📊 Domain Analysis

  Project: {framework} / {language}
  Test framework: {testFramework or "none detected"}
  Build tool: {buildTool or "none detected"}

  Detected domain: {domain description}
  Primary task type: {e.g., "feature implementation", "data transformation", "API integration"}

  Recommended pattern: {pattern name}
  Reason: {1-2 sentence rationale based on domain properties}

  Alternative: {second pattern name} — {brief reason it could also work}

Proceed with recommended pattern? (y / type alternative pattern name):
```

Wait for confirmation or alternative selection.

---

## Phase 3: Team Architecture Design

Load `${CLAUDE_PLUGIN_ROOT}/templates/references/agent-design-patterns.md` and apply the selected pattern.

Define 3–5 agents with specific roles based on the pattern:

For each agent, specify:
- **Name**: slug-style (e.g., `feature-planner`)
- **Role**: one-sentence description
- **Input**: what it receives (task description, code diff, spec file, etc.)
- **Output**: what it produces (implementation plan, test file, PR summary, etc.)
- **Tools**: Read, Edit, Bash, WebSearch, etc.
- **Model**: `sonnet` (default) or `opus` (for complex multi-step reasoning tasks)

Present the architecture for approval:

```
🏗 Agent Team Architecture: {pattern name}

  Pattern: {pattern name}
  Orchestrator: {domain}-orchestrator

  Agents:
  ┌─────────────────────────────────────────────────────┐
  │  {agent-1}   →  {agent-2}   →  {agent-3}           │
  │  [{role}]       [{role}]       [{role}]             │
  └─────────────────────────────────────────────────────┘

  Agent Details:
  1. {agent-1} (model: sonnet)
     Input:  {input}
     Output: {output}
     Tools:  {tools}

  2. {agent-2} (model: opus)
     Input:  {input}
     Output: {output}
     Tools:  {tools}

  3. {agent-3} (model: sonnet)
     Input:  {input}
     Output: {output}
     Tools:  {tools}

Approve architecture? (y/n/edit):
```

Wait for approval before writing any files.

---

## Phase 4: Generate Agent Definitions

For each agent in the approved architecture, create `.claude/agents/{name}.md`.

Agent file format:

```markdown
---
name: {name}
description: {role description} — triggers when {activation condition}
model: {sonnet|opus}
tools:
  - {tool1}
  - {tool2}
---

# {Name} Agent

## Role
{Expanded role description — 2-3 sentences}

## Input
{What this agent receives and from where}

## Output
{What this agent produces and where it saves/returns it}

## Instructions

1. {Step 1}
2. {Step 2}
3. {Step 3}

## Error Handling
- If input is missing: {fallback behavior}
- If tool fails: {recovery or escalation}
```

After creating all agent files:

```
✅ Agent definitions created:
  - .claude/agents/{agent-1}.md (model: sonnet)
  - .claude/agents/{agent-2}.md (model: opus)
  - .claude/agents/{agent-3}.md (model: sonnet)
```

---

## Phase 5: Generate Orchestrator

Load `${CLAUDE_PLUGIN_ROOT}/templates/references/orchestrator-templates.md` and select the template matching the approved pattern.

Fill in the template with:
- Domain name and description
- Agent list with activation conditions
- Sequencing or routing logic from the pattern
- Error handling and fallback paths

Save to `.claude/agents/{domain}-orchestrator.md`.

Show the orchestrator path and pattern used:

```
🎼 Orchestrator generated:
  File: .claude/agents/{domain}-orchestrator.md
  Pattern: {pattern name}
  Manages: {agent-1}, {agent-2}, {agent-3}
```

---

## Phase 6: Register in CLAUDE.md

Append an agent team section to `CLAUDE.md`:

```markdown
## Agent Team: {Domain} ({pattern name})

Orchestrator: `.claude/agents/{domain}-orchestrator.md`
Pattern: {pattern name}

Agents:
- `{agent-1}` — {role} (model: sonnet)
- `{agent-2}` — {role} (model: opus)
- `{agent-3}` — {role} (model: sonnet)

Activation: "{activation phrase}"
```

Preserve all existing CLAUDE.md content. Only append — never overwrite.

Check that the updated CLAUDE.md stays under 80 lines. If it would exceed 80 lines, summarize the agent team section more concisely.

---

## Phase 7: Update Config

Add each generated agent to `.harnesskit/config.json` → `customAgents` array.

For each agent, append an entry:

```json
{
  "name": "{name}",
  "file": ".claude/agents/{name}.md",
  "createdAt": "{ISO timestamp}",
  "team": "{domain}",
  "pattern": "{pattern name}",
  "type": "{orchestrator|specialist|utility}"
}
```

Write the orchestrator entry with `"type": "orchestrator"`.
Write specialist agents with `"type": "specialist"`.
Write utility/support agents with `"type": "utility"`.

Preserve all existing `customAgents` entries — only append new ones.

---

## Phase 8: Validation Summary

Show a complete summary of everything created:

```
═══ Agent Team Created ═══

  Domain:      {domain description}
  Pattern:     {pattern name}
  Agents:      {count}

  Files Created:
  ├ .claude/agents/{agent-1}.md         (sonnet)
  ├ .claude/agents/{agent-2}.md         (opus)
  ├ .claude/agents/{agent-3}.md         (sonnet)
  └ .claude/agents/{domain}-orchestrator.md

  CLAUDE.md:   ✅ Agent team section appended
  config.json: ✅ {count} entries added to customAgents

  Activation phrase: "{phrase}"

  To use: tell Claude "{activation phrase}" and the orchestrator
  will coordinate your agent team automatically.

══════════════════════════════
```

Log completion to `.harnesskit/current-session.jsonl`:
```json
{"type":"feature_done","id":"architect:{domain}"}
```
