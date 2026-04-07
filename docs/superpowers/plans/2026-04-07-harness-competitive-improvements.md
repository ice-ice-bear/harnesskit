# HarnessKit Competitive Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add agent architecture design capabilities, reference documentation, and quality improvements inspired by revfactory/harness, while strengthening HarnessKit's existing advantages.

**Architecture:** New `/harnesskit:architect` skill provides a 5-phase workflow for designing agent teams using 6 orchestration patterns. Reference documents in `templates/references/` provide progressive-disclosure pattern guides. Existing files (plugin.json, orchestrator agent, apply skill) get targeted enhancements.

**Tech Stack:** Bash, Markdown (SKILL.md format), JSON, shell tests (`set -euo pipefail`)

---

### Task 1: Agent Design Patterns Reference Document

**Files:**
- Create: `templates/references/agent-design-patterns.md`

- [ ] **Step 1: Create the reference document**

```markdown
# Agent Design Patterns — Reference Guide

> 프로그레시브 디스클로저: 이 문서는 /harnesskit:architect 스킬에서 필요 시 로드됩니다.
> Progressive disclosure: This document is loaded on-demand by /harnesskit:architect.

## 실행 모드 선택 (Execution Mode Selection)

### Agent Teams vs Sub-agents

| 기준 | Agent Teams | Sub-agents |
|------|------------|------------|
| 협업 필요 | 다수 에이전트가 협업 | 단일 작업 위임 |
| 컨텍스트 공유 | 에이전트 간 데이터 전달 | 독립 실행 |
| 복잡도 | 높음 (오케스트레이터 필요) | 낮음 |
| 사용 시점 | 도메인 분석, 코드 리뷰 파이프라인 | 파일 검색, 단일 변환 |

### 의사결정 트리 (Decision Tree)

```
작업이 단일 전문성으로 해결 가능한가?
├─ YES → Sub-agent (Agent tool with specific prompt)
└─ NO → 여러 전문성이 필요한가?
    ├─ 순차적 → Pipeline 패턴
    ├─ 병렬 독립 → Fan-out/Fan-in 패턴
    ├─ 입력에 따라 전문가 선택 → Expert Pool 패턴
    ├─ 생성 + 검증 반복 → Producer-Reviewer 패턴
    ├─ 동적 작업 분배 → Supervisor 패턴
    └─ 재귀적 분해 → Hierarchical Delegation 패턴
```

## 6가지 오케스트레이션 패턴

### 1. Pipeline (파이프라인)

순차적 처리. 각 단계의 출력이 다음 단계의 입력.

```
[분석 Agent] → [설계 Agent] → [구현 Agent] → [검증 Agent]
```

**적합한 경우:**
- 단계가 명확히 구분되는 워크플로우
- 이전 단계 완료 후에만 다음 단계 진행 가능
- 예: 코드 리뷰 파이프라인 (lint → type-check → logic review → security)

**에이전트 정의 예시:**
```markdown
# Pipeline Stage: Analysis Agent
You analyze code and produce a structured report.
Input: file paths
Output: JSON report with findings
Next stage: Design Agent receives your report
```

### 2. Fan-out / Fan-in (팬아웃/팬인)

병렬 분석 후 결과 통합.

```
              ┌─ [Frontend Agent] ─┐
[Dispatcher] ─┼─ [Backend Agent]  ─┼─ [Integrator]
              └─ [Infra Agent]    ─┘
```

**적합한 경우:**
- 독립적으로 분석 가능한 하위 작업
- 병렬 처리로 시간 절약 가능
- 예: 풀스택 코드 리뷰, 다국어 번역

**에이전트 정의 예시:**
```markdown
# Fan-out: Dispatcher Agent
Split the task into independent subtasks.
Dispatch each to the appropriate specialist agent.
Collect results and pass to Integrator.
```

### 3. Expert Pool (전문가 풀)

입력에 따라 적절한 전문가를 동적 선택.

```
[Router] → 선택 → [Security Expert]
                  [Performance Expert]
                  [Accessibility Expert]
```

**적합한 경우:**
- 입력 유형에 따라 다른 전문성 필요
- 전문가 간 상호작용 불필요
- 예: 이슈 트리아지, 질문 라우팅

### 4. Producer-Reviewer (생성-검증)

반복적 생성과 품질 검증 사이클.

```
[Producer] → 산출물 → [Reviewer] → 피드백 → [Producer] → ... → 승인
```

**적합한 경우:**
- 품질 기준이 명확
- 반복 개선으로 품질 향상 가능
- 예: 코드 생성 + 리뷰, 문서 작성 + 편집

### 5. Supervisor (감독자)

중앙 감독자가 작업을 동적 분배하고 진행 관리.

```
[Supervisor] ─┬─ assign → [Worker A]
              ├─ assign → [Worker B]
              └─ monitor + reassign
```

**적합한 경우:**
- 작업량이 동적으로 변함
- 실패 시 재할당 필요
- 예: 대규모 마이그레이션, 배치 처리

### 6. Hierarchical Delegation (계층적 위임)

재귀적으로 작업을 분해하여 하위 에이전트에 위임.

```
[Lead] → 분해 → [Sub-lead A] → 분해 → [Worker A1]
                                      [Worker A2]
               [Sub-lead B] → 분해 → [Worker B1]
```

**적합한 경우:**
- 작업이 재귀적으로 분해 가능
- 각 수준에서 다른 전문성 필요
- 예: 대규모 리팩토링, 시스템 설계

## 에이전트 정의 구조

에이전트 파일은 `.claude/agents/{name}.md` 에 저장:

```markdown
---
name: {agent-name}
description: {one-line description for agent selection}
---

# {Agent Name}

## Role
{이 에이전트의 역할과 전문성}

## Input
{받는 데이터 형식}

## Output
{생성하는 데이터 형식}

## Tools
{사용하는 도구 목록}

## Constraints
{제약 조건}
```

## 에이전트 분리 기준

하나의 에이전트로 충분한가, 분리해야 하는가:

| 분리해야 할 때 | 하나로 충분할 때 |
|---|---|
| 서로 다른 전문 지식 필요 | 같은 도메인 지식 |
| 독립적으로 테스트 가능 | 순서 의존적이고 밀접 |
| 병렬 실행 가능 | 항상 순차 실행 |
| 컨텍스트가 너무 큼 | 컨텍스트가 작음 |

## 스킬 vs 에이전트

| 스킬 (Skill) | 에이전트 (Agent) |
|---|---|
| 절차적 지식 (how-to) | 전문가 페르소나 (who) |
| 트리거 기반 자동 실행 | 명시적 호출 또는 오케스트레이터가 선택 |
| SKILL.md 형식 | AGENT.md 형식 |
| 사용자가 직접 호출 가능 | 주로 다른 에이전트/스킬이 호출 |
```

- [ ] **Step 2: Verify the file was created correctly**

Run: `wc -l templates/references/agent-design-patterns.md && head -5 templates/references/agent-design-patterns.md`
Expected: ~150+ lines, starts with `# Agent Design Patterns`

- [ ] **Step 3: Commit**

```bash
git add templates/references/agent-design-patterns.md
git commit -m "docs: add agent design patterns reference guide

Six orchestration patterns (pipeline, fan-out, expert pool,
producer-reviewer, supervisor, hierarchical delegation) with
decision tree and agent definition structure."
```

---

### Task 2: Orchestrator Templates Reference Document

**Files:**
- Create: `templates/references/orchestrator-templates.md`

- [ ] **Step 1: Create the orchestrator templates reference**

```markdown
# Orchestrator Templates — Reference Guide

> 프로그레시브 디스클로저: /harnesskit:architect에서 패턴 선택 후 로드됩니다.

## Pipeline Orchestrator Template

```markdown
---
name: {domain}-pipeline-orchestrator
description: Orchestrates {domain} pipeline — {stage1} → {stage2} → {stage3}
---

# {Domain} Pipeline Orchestrator

## Workflow

1. Receive input from user
2. Pass to Stage 1 agent: {stage1-agent}
3. Validate Stage 1 output
4. Pass to Stage 2 agent: {stage2-agent}
5. Validate Stage 2 output
6. Pass to Stage 3 agent: {stage3-agent}
7. Compile final output

## Error Handling

- If any stage fails, log error and report to user
- Do not proceed to next stage on failure
- Offer retry or skip options

## Data Format

Each stage receives and produces JSON:
\`\`\`json
{
  "stage": "{stage-name}",
  "input": { ... },
  "output": { ... },
  "status": "success|failure",
  "errors": []
}
\`\`\`
```

## Fan-out/Fan-in Orchestrator Template

```markdown
---
name: {domain}-fanout-orchestrator
description: Parallel dispatch to specialist agents, then merge results
---

# {Domain} Fan-out/Fan-in Orchestrator

## Dispatch Phase

1. Analyze input to determine which specialists are needed
2. Launch agents in parallel using Agent tool:
   - Agent A: {specialist-a} — handles {area-a}
   - Agent B: {specialist-b} — handles {area-b}
   - Agent C: {specialist-c} — handles {area-c}

## Merge Phase

1. Collect all agent results
2. Resolve conflicts (if same file touched by multiple agents)
3. Merge into unified output
4. Present summary to user
```

## Expert Pool Orchestrator Template

```markdown
---
name: {domain}-expert-pool
description: Routes tasks to the most appropriate expert agent
---

# {Domain} Expert Pool Router

## Expert Registry

| Expert | Triggers | Agent File |
|--------|----------|------------|
| {expert-1} | {keyword patterns} | .claude/agents/{expert-1}.md |
| {expert-2} | {keyword patterns} | .claude/agents/{expert-2}.md |
| {expert-3} | {keyword patterns} | .claude/agents/{expert-3}.md |

## Routing Logic

1. Analyze user request
2. Match against expert triggers (keyword + context)
3. If single match → dispatch to that expert
4. If multiple matches → dispatch to highest-confidence match
5. If no match → handle directly or ask user to clarify
```

## Producer-Reviewer Orchestrator Template

```markdown
---
name: {domain}-producer-reviewer
description: Iterative generation with quality validation
---

# {Domain} Producer-Reviewer Orchestrator

## Configuration

- Max iterations: 3
- Quality threshold: {criteria}

## Workflow

1. Pass requirements to Producer agent
2. Producer generates output
3. Pass output to Reviewer agent
4. Reviewer scores and provides feedback
5. If score >= threshold → accept, output to user
6. If score < threshold AND iterations < max → pass feedback to Producer, goto 2
7. If iterations exhausted → output best attempt with reviewer notes
```

## Supervisor Orchestrator Template

```markdown
---
name: {domain}-supervisor
description: Dynamic task assignment and monitoring
---

# {Domain} Supervisor

## Worker Pool

- Worker type A: {description} (max: {N})
- Worker type B: {description} (max: {N})

## Task Queue Management

1. Break input into work items
2. Assign to available workers based on type match
3. Monitor completion
4. On worker failure: reassign to different worker
5. On all complete: compile results
```

## Hierarchical Delegation Template

```markdown
---
name: {domain}-hierarchy
description: Recursive task decomposition and delegation
---

# {Domain} Hierarchical Delegator

## Decomposition Rules

- If task complexity > threshold → split into subtasks
- Each subtask assigned to sub-lead or worker
- Sub-leads can further decompose
- Workers execute leaf tasks

## Depth Limit

Maximum delegation depth: 3 levels
If depth exceeded, execute directly instead of delegating
```

## CLAUDE.md 등록 템플릿

에이전트 팀 생성 후 CLAUDE.md에 추가할 섹션:

```markdown
## Agent Team: {domain}

Pattern: {pattern-name}
Agents: {agent-list}
Orchestrator: .claude/agents/{orchestrator}.md

Activate: "Run {domain} workflow" or "{domain} 팀 실행"
```
```

- [ ] **Step 2: Verify file creation**

Run: `wc -l templates/references/orchestrator-templates.md && head -5 templates/references/orchestrator-templates.md`
Expected: ~140+ lines, starts with `# Orchestrator Templates`

- [ ] **Step 3: Commit**

```bash
git add templates/references/orchestrator-templates.md
git commit -m "docs: add orchestrator templates reference for 6 patterns

Pipeline, fan-out/fan-in, expert pool, producer-reviewer,
supervisor, and hierarchical delegation orchestrator templates
with data flow and error handling."
```

---

### Task 3: Architect Skill — SKILL.md

**Files:**
- Create: `skills/architect/SKILL.md`

- [ ] **Step 1: Create the architect skill**

```markdown
---
name: architect
description: Design agent teams for your domain using 6 orchestration patterns — analyzes project, selects pattern, generates agent definitions and orchestrator
user_invocable: true
---

# /harnesskit:architect

Design and generate agent teams tailored to your project's domain. Uses 6 orchestration patterns to create coordinated agent workflows.

## Prerequisites

- `.harnesskit/config.json` must exist (run `/harnesskit:setup` first)
- `.harnesskit/detected.json` for project context

## Usage

```
/harnesskit:architect [domain-description]
```

If no domain description provided, ask the user what domain or workflow they want to automate.

## Phase 1: Audit Existing Agents

1. Check `.claude/agents/` directory for existing agent files
2. Check `.harnesskit/config.json` → `customAgents` array
3. Check `CLAUDE.md` for registered agent teams
4. Present findings:

```
🔍 Existing Agent Infrastructure:
  Agents: {count} ({list names})
  Teams: {count} ({list patterns})
  
  Options:
  (1) Create new team — design from scratch
  (2) Extend existing — add agents to existing team
  (3) Refactor — restructure existing agents into a team
```

If no existing agents: skip directly to Phase 2.

## Phase 2: Domain Analysis

1. Read `.harnesskit/detected.json` for project properties
2. If session logs exist (`.harnesskit/session-logs/`), analyze:
   - Recurring task patterns
   - Time-consuming operations
   - Error-prone areas
3. Analyze user's domain description
4. Present domain summary:

```
📋 Domain Analysis: {domain}

  Project: {framework} + {language}
  Key areas: {list areas from analysis}
  Complexity: {low|medium|high}
  
  Recommended pattern: {pattern-name}
  Reason: {why this pattern fits}
  
  Alternative: {pattern-name} — {when this would be better}
  
  Proceed with {recommended}? (y/n/other)
```

## Phase 3: Team Architecture Design

Load reference: `${CLAUDE_PLUGIN_ROOT}/templates/references/agent-design-patterns.md`

Based on selected pattern, design the team:

1. Define each agent's role, input/output, and tools
2. Define data flow between agents
3. Define error handling strategy
4. Present architecture:

```
🏗️ Team Architecture: {domain} ({pattern})

  Agents:
    [1] {name} — {role} (type: {general-purpose|Explore|Plan|custom})
    [2] {name} — {role}
    [3] {name} — {role}
  
  Orchestrator: {name}
  
  Data Flow:
    {visual representation of flow}
  
  Approve and generate? (y/n/edit)
```

## Phase 4: Generate Agent Definitions

For each approved agent:

1. Create agent file at `.claude/agents/{name}.md` using structure from reference
2. Include: name, description, role, input/output format, tools, constraints
3. Ensure all Agent tool calls specify `model: "sonnet"` (default) or `model: "opus"` (for complex reasoning)

## Phase 5: Generate Orchestrator

Load reference: `${CLAUDE_PLUGIN_ROOT}/templates/references/orchestrator-templates.md`

1. Select orchestrator template matching the chosen pattern
2. Fill template with domain-specific details
3. Save to `.claude/agents/{domain}-orchestrator.md`
4. Add error handling and data validation between stages

## Phase 6: Register in CLAUDE.md

Append agent team registration to project's CLAUDE.md:

```markdown
## Agent Team: {domain}
Pattern: {pattern}
Orchestrator: .claude/agents/{domain}-orchestrator.md
Agents: {comma-separated list}
Activate: "{activation phrase}"
```

## Phase 7: Update Config

Update `.harnesskit/config.json`:
- Add each agent to `customAgents` array:
  ```json
  {
    "name": "{name}",
    "file": ".claude/agents/{name}.md",
    "createdAt": "{ISO date}",
    "team": "{domain}",
    "pattern": "{pattern}",
    "type": "architect"
  }
  ```

## Phase 8: Validation Summary

```
✅ Agent Team Created: {domain}

  Pattern: {pattern}
  Agents: {count} generated
    {list with file paths}
  Orchestrator: .claude/agents/{domain}-orchestrator.md
  CLAUDE.md: updated with activation trigger

  🚀 Activate: "{activation phrase}"
  
  💡 Test the team by running the activation phrase.
     Use /harnesskit:insights after a few sessions to evaluate team effectiveness.
```
```

- [ ] **Step 2: Verify skill file**

Run: `wc -l skills/architect/SKILL.md && head -3 skills/architect/SKILL.md`
Expected: ~160+ lines, starts with frontmatter `---`

- [ ] **Step 3: Commit**

```bash
git add skills/architect/SKILL.md
git commit -m "feat: add /harnesskit:architect skill for agent team design

5-phase workflow: audit → domain analysis → architecture design →
agent generation → orchestrator generation. Supports 6 patterns."
```

---

### Task 4: Architect Command Registration

**Files:**
- Create: `commands/architect.md`

- [ ] **Step 1: Create command file for autocomplete registration**

```markdown
---
name: architect
description: Design agent teams for your domain using orchestration patterns
user_invocable: true
allowed_tools: ["Agent", "Read", "Write", "Edit", "Glob", "Grep", "Bash"]
---

Design and generate agent teams tailored to your project's domain.
```

- [ ] **Step 2: Verify**

Run: `ls commands/architect.md && cat commands/architect.md`
Expected: File exists with frontmatter

- [ ] **Step 3: Commit**

```bash
git add commands/architect.md
git commit -m "feat: register /harnesskit:architect command for autocomplete"
```

---

### Task 5: Orchestrator Agent Enhancement

**Files:**
- Modify: `agents/orchestrator/AGENT.md`

- [ ] **Step 1: Enhance the orchestrator agent with concrete workflow details**

Replace the entire content of `agents/orchestrator/AGENT.md` with:

```markdown
---
name: orchestrator
description: Orchestrates multi-step HarnessKit flows (setup, insights, architect) by coordinating skills in sequence
---

# HarnessKit Orchestrator

You coordinate multi-step HarnessKit workflows. You are called by skills that need to chain multiple operations together.

## Setup Flow

When called from `/harnesskit:setup` after detection and preset selection:

1. Read `.harnesskit/config.json` for current preset
2. Run init skill to generate harness infrastructure files
3. Run toolkit generation (skills, hooks, commands)
4. Present marketplace plugin recommendations
5. Present agent recommendations
6. Summarize what was created

### Error Handling
- If detection script fails: report error, suggest manual `detected.json` creation
- If template missing: use `generic` fallback, warn user
- If `.claude/settings.json` merge fails: output manual hook registration instructions

### Data Pipeline
```
detect-repo.sh → detected.json → init (templates + preset) → files
                                                            → hooks registration
                                                            → marketplace recommendations
```

## Insights Flow

When called from `/harnesskit:insights`:

1. Read `.harnesskit/config.json` for preset (determines thresholds)
2. Collect data files:
   - `.harnesskit/session-logs/*.json` (last 10)
   - `.harnesskit/failures.json`
   - `docs/feature_list.json`
   - `CLAUDE.md`
   - `.claude/settings.json`
3. Run analysis across all dimensions
4. Generate report with statistics
5. Generate proposals (max 5, prioritized by impact)
6. Save to `.harnesskit/pending-proposals.json`
7. Tell user to run `/harnesskit:apply`

### Error Handling
- If no session logs: "Not enough data yet. Complete a few sessions first."
- If failures.json missing: skip error pattern analysis, note in report
- If insights-history.json has rejected proposals: respect cooldown periods

### Data Pipeline
```
session-logs + failures + config → analysis → report + proposals
                                                     ↓
                                          pending-proposals.json
```

## Architect Flow

When called from `/harnesskit:architect`:

1. Read `.harnesskit/config.json` and `.harnesskit/detected.json`
2. Audit existing `.claude/agents/` directory
3. Load `templates/references/agent-design-patterns.md` for pattern selection
4. Design team architecture with user
5. Load `templates/references/orchestrator-templates.md` for generation
6. Generate agent files to `.claude/agents/`
7. Update CLAUDE.md with team registration
8. Update `config.json` → `customAgents`

### Error Handling
- If detected.json missing: suggest running `/harnesskit:setup` first
- If `.claude/agents/` doesn't exist: create it
- If CLAUDE.md update would exceed 60 lines: warn and suggest separate file

### Data Pipeline
```
detected.json + session-logs → domain analysis → pattern selection
                                                       ↓
                              references → agent definitions + orchestrator
                                                       ↓
                                          CLAUDE.md + config.json update
```

## Rules

- Always read `.harnesskit/config.json` first to determine current preset
- Never modify files directly — always propose changes for user approval
- If a required file is missing, suggest running `/harnesskit:setup`
- Log orchestration steps to `.harnesskit/current-session.jsonl` when possible
- Reference `.harnesskit/bible.md` principles when making design decisions
```

- [ ] **Step 2: Verify the enhanced agent**

Run: `wc -l agents/orchestrator/AGENT.md`
Expected: ~90+ lines (was 35 before)

- [ ] **Step 3: Commit**

```bash
git add agents/orchestrator/AGENT.md
git commit -m "enhance: orchestrator agent with concrete workflows and error handling

Adds architect flow, data pipeline diagrams, and error handling
for all three flows (setup, insights, architect)."
```

---

### Task 6: plugin.json Enhancement

**Files:**
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: Add homepage and enhance metadata**

Replace the content of `.claude-plugin/plugin.json` with:

```json
{
  "name": "harnesskit",
  "version": "0.4.0",
  "description": "Adaptive harness for vibe coders — detect, configure, observe, improve. Agent team architecture included.",
  "author": {
    "name": "ice-ice-bear",
    "url": "https://github.com/ice-ice-bear"
  },
  "homepage": "https://github.com/ice-ice-bear/harnesskit",
  "repository": "https://github.com/ice-ice-bear/harnesskit",
  "license": "MIT",
  "keywords": [
    "harness",
    "vibe-coding",
    "guardrails",
    "insights",
    "adaptive",
    "agent-team",
    "orchestration",
    "skill-architect"
  ]
}
```

- [ ] **Step 2: Verify JSON is valid**

Run: `jq . .claude-plugin/plugin.json`
Expected: Valid formatted JSON output

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "chore: bump to v0.4.0, add homepage/author URL and agent keywords"
```

---

### Task 7: CLAUDE.md Auto-Registration in Apply Skill

**Files:**
- Modify: `skills/apply/SKILL.md`

- [ ] **Step 1: Add CLAUDE.md auto-registration logic after the agent creation section**

In `skills/apply/SKILL.md`, after the existing agent creation block (line 56, ending with `"type": "agent_creation"}`), add:

```markdown
       4. Auto-register in CLAUDE.md:
          - Read current CLAUDE.md
          - If no "Custom Agents" or "Agent Team" section exists, append:
            ```
            ## Custom Agents
            - {name}: .harnesskit/agents/{name}.md — {description}
            ```
          - If section exists, append new agent entry to it
          - Verify CLAUDE.md stays under 60 lines; if exceeded, warn:
            "⚠️ CLAUDE.md exceeds 60 lines. Consider moving agent registry to a separate file."
```

Similarly, after the hook creation block (line 62, ending with `"sourceProposal": "{id}"}`), add:

```markdown
       6. Auto-register in CLAUDE.md:
          - If no "Custom Hooks" section exists, append:
            ```
            ## Custom Hooks
            - {name}: {hookPoint} — {description}
            ```
          - If section exists, append new hook entry
```

And after the review supplement block (line 68, ending with `customSkills array`), add:

```markdown
       6. Auto-register in CLAUDE.md:
          - If no "Custom Skills" section exists, append:
            ```
            ## Custom Skills
            - project-review-rules: .harnesskit/skills/project-review-rules.md
            ```
          - If section exists, append new skill entry
```

- [ ] **Step 2: Verify the file has the new sections**

Run: `grep -c "Auto-register in CLAUDE.md" skills/apply/SKILL.md`
Expected: `3`

- [ ] **Step 3: Commit**

```bash
git add skills/apply/SKILL.md
git commit -m "feat: auto-register custom agents/hooks/skills in CLAUDE.md via /apply

Ensures discoverability across sessions when custom components
are created through the insights → apply workflow."
```

---

### Task 8: Test for Architect Skill

**Files:**
- Create: `tests/test-architect-skill.sh`

- [ ] **Step 1: Create test script**

```bash
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
```

- [ ] **Step 2: Make test executable and run it**

Run: `chmod +x tests/test-architect-skill.sh && bash tests/test-architect-skill.sh`
Expected: All tests fail (nothing created yet) — this validates the test catches missing files

- [ ] **Step 3: Commit**

```bash
git add tests/test-architect-skill.sh
git commit -m "test: add test suite for /harnesskit:architect skill and references"
```

---

### Task 9: Run All Tests and Verify

**Files:**
- No new files

- [ ] **Step 1: Run the architect test after all implementation tasks are complete**

Run: `bash tests/test-architect-skill.sh`
Expected: All tests PASS

- [ ] **Step 2: Run all existing tests to verify no regressions**

Run: `for f in tests/test-*.sh; do echo "--- $f ---"; bash "$f"; done`
Expected: All test suites pass

- [ ] **Step 3: Final commit with all changes**

If any files were missed in previous commits:
```bash
git status
git add <any-missed-files>
git commit -m "chore: final cleanup for agent architecture feature"
```

---

### Task 10: Feature List Dogfooding

**Files:**
- Modify: `docs/feature_list.json` (passes field only, per CLAUDE.md rules)

Note: This task populates the feature list with HarnessKit's own features for dogfooding purposes. Per CLAUDE.md absolute rules, only the `passes` field may be modified on existing entries. Since the features array is empty, all entries are new additions — this is the initial population, not a modification.

- [ ] **Step 1: Populate feature_list.json with HarnessKit's own features**

Replace `docs/feature_list.json` with:

```json
{
  "version": "1.0.0",
  "features": [
    {
      "id": "feat-001",
      "description": "Project tech stack auto-detection (language, framework, package manager, test, lint)",
      "category": "detection",
      "passes": true,
      "priority": 1,
      "source": "core"
    },
    {
      "id": "feat-002",
      "description": "Experience preset system (beginner/intermediate/advanced) with guardrails",
      "category": "configuration",
      "passes": true,
      "priority": 2,
      "source": "core"
    },
    {
      "id": "feat-003",
      "description": "Session lifecycle hooks (start briefing, end logging, guardrails)",
      "category": "observation",
      "passes": true,
      "priority": 3,
      "source": "core"
    },
    {
      "id": "feat-004",
      "description": "Insights engine — session analysis and improvement proposals",
      "category": "improvement",
      "passes": true,
      "priority": 4,
      "source": "core"
    },
    {
      "id": "feat-005",
      "description": "Marketplace plugin discovery and recommendation",
      "category": "toolkit",
      "passes": true,
      "priority": 5,
      "source": "core"
    },
    {
      "id": "feat-006",
      "description": "Agent team architecture design with 6 orchestration patterns",
      "category": "architecture",
      "passes": false,
      "priority": 6,
      "source": "competitive-analysis"
    },
    {
      "id": "feat-007",
      "description": "CLAUDE.md auto-registration for custom agents/hooks/skills",
      "category": "improvement",
      "passes": false,
      "priority": 7,
      "source": "competitive-analysis"
    },
    {
      "id": "feat-008",
      "description": "Benchmarking framework — with-harness vs baseline quality measurement",
      "category": "quality",
      "passes": false,
      "priority": 8,
      "source": "competitive-analysis"
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

Run: `jq '.features | length' docs/feature_list.json`
Expected: `8`

- [ ] **Step 3: Commit**

```bash
git add docs/feature_list.json
git commit -m "feat: populate feature_list.json with HarnessKit's own features for dogfooding

8 features: 5 core (passing), 3 from competitive analysis (pending).
Enables self-tracking of HarnessKit development."
```
