# v2b — Extended Harness Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 4 extended features to HarnessKit: A/B eval testing, PRD decomposition, worktree isolation, and a curated bible guideline.

**Architecture:** All v2b features are skill-based (markdown). No new hooks or shell scripts. 2 new skills (prd.md, worktree.md), 1 new template (bible.md), and modifications to existing skills (apply.md, init.md, insights.md). Plugin version bumps to 0.2.0.

**Tech Stack:** Markdown (skills), JSON, Claude Code Plugin SDK

**Spec:** `docs/superpowers/specs/2026-03-20-harnesskit-v2b-design.md`

**Depends on:** v2a fully implemented (89 tests passing)

---

## File Structure

```
New files:
├── harnesskit/skills/prd.md                    # /harnesskit:prd command
├── harnesskit/skills/worktree.md               # /harnesskit:worktree command
└── harnesskit/templates/bible.md               # Curated principles reference

Modified files:
├── harnesskit/skills/apply.md                  # A/B eval prompt for skill proposals
├── harnesskit/skills/init.md                   # bible.md copy step + schemaVersion 2.1
├── harnesskit/skills/insights.md               # Worktree suggestion in Feature Progress
└── harnesskit/plugin.json                      # Register prd + worktree, version 0.2.0
```

---

### Task 1: bible.md — Curated Principles Template

**Files:**
- Create: `harnesskit/templates/bible.md`

- [ ] **Step 1: Create the bible template**

Create `harnesskit/templates/bible.md` with this exact content:

```markdown
# HarnessKit Bible — Harness Engineering Principles

> 이 문서는 참조용 원칙 모음입니다. 파일 구조나 형식 지침은 CLAUDE.md와 HarnessKit 템플릿을 따르세요.
> 출처: Claude Code 실전 가이드, Vibe Coding Fundamentals

## 1. 컨텍스트 관리
- Fresh context > bloated context (컨텍스트는 우유 — 시간이 지나면 상한다)
- Lazy Loading: 목차를 주고, 전체 매뉴얼을 주지 않는다
- MCP 다이어트: 동시 활성 5-6개로 제한, 미사용 MCP 비활성화

## 2. 세션 위생
- One session = one feature (예: "Stripe webhook handler", NOT "전체 결제 시스템")
- /clear로 feature 완료 후 리셋
- /compact를 전략적 시점에 실행 (자동 압축에 의존하지 않음)
- 토큰 사용량을 /statusline으로 지속 모니터링

## 3. 작업 설계
- 반복적 소단위: 전체 feature 한 번에 요청하지 않음
- 검증 가능한 출력: TDD — 가정이 아닌 테스트로 검증
- Plan Mode → Implementation 분리: 계획 세션과 구현 세션을 나눔
- Claude의 사고 과정 무시하지 않기: 잘못된 가정은 Escape로 중단

## 4. 지식 아키텍처
- CLAUDE.md = 팀 공유 규칙 (간결하게)
- MEMORY.md = 개인 선호/패턴 (자동 관리)
- TODO.md / progress files = 세션 간 작업 연속성
- feature_list.json = passes: false 패턴으로 작업 추적
- Mermaid 다이어그램: 산문보다 다이어그램으로 시스템 구조 표현

## 5. 자동화 철학
- Zero-token hooks: 경량 감지는 shell (bash + jq)
- Claude는 판단이 필요한 분석에만 (insights 트리거 시)
- WAT 프레임워크: Workflow → Agent → Tools (단계별 정의)
- 작은 단일 작업 스크립트 > 모놀리식 도구

## 6. 툴킷 철학
- Marketplace First, Customize Later
- 바퀴를 재발명하지 않는다
- 산출물이 아닌 생성 시스템을 구축한다 (재현 가능한 워크플로우)
- 모델 선택: Haiku(간단) → Sonnet(일반) → Opus(설계/복잡)

## 7. 안티패턴
- CLAUDE.md에 모든 것을 넣지 않는다
- 자동 압축에 의존하지 않는다
- 전체 feature를 한 번에 요청하지 않는다
- 스택 트레이스를 해석하지 말고 전체를 붙여넣는다
- 외부 데이터 읽기 시 Prompt Injection 주의
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/templates/bible.md
git commit -m "feat(v2b): add curated bible template — harness engineering principles"
```

---

### Task 2: init.md — Bible Copy + Schema Version

**Files:**
- Modify: `harnesskit/skills/init.md`

- [ ] **Step 1: Read current init.md**

- [ ] **Step 2: Add bible copy step**

In the Harness Infrastructure section, after step 7 (v2a fields), add:

```markdown
8. **Bible reference** — copy `templates/bible.md` to `.harnesskit/bible.md`
   - This is a fixed reference document, not user-modifiable
```

- [ ] **Step 3: Add bible reference to CLAUDE.md generation**

In step 1 (CLAUDE.md generation), after "Apply preset filter: full/concise/minimal detail level", add:

```markdown
   - Append bible reference line: `For harness engineering principles → .harnesskit/bible.md`
```

- [ ] **Step 4: Update schema version conditional**

Replace the current step 7 condition:
```
7. **v2a fields in .harnesskit/config.json** — if `schemaVersion` is missing or < "2.0", add:
   - `schemaVersion`: `"2.0"`
```

With:
```
7. **v2a/v2b fields in .harnesskit/config.json** — if `schemaVersion` is missing or < "2.1", add:
   - `schemaVersion`: `"2.1"`
   - (all existing v2a fields: uncoveredAreas, reviewInternalization, customHooks, customSkills, customAgents, removedPlugins)
   - `bibleInstalled`: `true`
```

This handles fresh installs AND upgrades from v2a (2.0) in one conditional.

- [ ] **Step 5: Add v2a→v2b migration block**

In the "Migration from v1" section at the end of init.md, add after it:

```markdown
### Migration from v2a

If `.harnesskit/config.json` has `schemaVersion: "2.0"`:
1. This is a v2a project upgrading to v2b
2. Copy `templates/bible.md` to `.harnesskit/bible.md`
3. Add bible reference to CLAUDE.md (append line)
4. Update config.json:
   - `schemaVersion`: `"2.1"`
   - `bibleInstalled`: `true`
5. Output: "✅ Migrated to v2b schema. Bible installed."
```

- [ ] **Step 6: Commit**

```bash
git add harnesskit/skills/init.md
git commit -m "feat(v2b): add bible copy step, schema 2.1, v2a→v2b migration to init.md"
```

---

### Task 3: prd.md — PRD Decomposition Skill

**Files:**
- Create: `harnesskit/skills/prd.md`

- [ ] **Step 1: Create the PRD skill**

Create `harnesskit/skills/prd.md`:

```markdown
---
name: prd
description: Decompose a PRD document into GitHub issues and feature_list.json entries
user_invocable: true
---

# /harnesskit:prd

Decompose a Product Requirements Document into discrete features, create GitHub issues, and populate feature_list.json.

## Usage

```
/harnesskit:prd [path-to-prd.md]
```

If no path provided, ask the user to provide a file path or paste PRD content.

## Prerequisites

- `.harnesskit/config.json` must exist (HarnessKit initialized)
- GitHub MCP: optional (if unavailable, skip issue creation, only populate feature_list.json)

## Instructions

1. Read the PRD document
2. Analyze and decompose into discrete features/tasks
3. For each feature, prepare:
   - `id`: auto-increment from existing feature_list.json (feat-001, feat-002, ...)
   - `description`: clear, actionable description
   - `category`: derived from PRD section
   - `steps`: breakdown into implementation steps
   - `passes`: `false`
   - `priority`: order from PRD (1 = highest)
   - `githubIssue`: null (populated after issue creation)
   - `source`: `"prd"`

4. **Duplicate detection**: Before creating, check existing feature_list.json:
   - Compare `description` of new features against existing ones
   - If similar feature exists: "Feature '{description}' already exists (feat-XXX). Skip? (y/n)"
   - If GitHub MCP available: also search existing issues by title

5. Present decomposition for approval:
   ```
   📋 PRD Decomposition: {prd_name}

   Found {count} features:
     [1] {description} (priority: {N})
     [2] {description} (priority: {N})
     ...

   Create GitHub issues + feature_list entries? (y/n/edit)
   ```

6. On approval:
   - If GitHub MCP available:
     - Create issue for each feature (title = description, body = steps, labels = [category])
     - Record issue number in `githubIssue` field
   - If GitHub MCP unavailable:
     - Skip issue creation, output: "⚠️ GitHub MCP not available. Feature list populated without issues."
   - Append all features to `docs/feature_list.json`

7. Output summary:
   ```
   ✅ PRD decomposed:
     - Features created: {count}
     - GitHub issues: {count or "skipped (no GitHub MCP)"}
     - feature_list.json updated

   🚀 Start with: feat-{first_id} ({first_description})
   ```
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/prd.md
git commit -m "feat(v2b): add /harnesskit:prd skill — PRD to GitHub issues + feature_list"
```

---

### Task 4: worktree.md — Harness-Aware Worktree Skill

**Files:**
- Create: `harnesskit/skills/worktree.md`

- [ ] **Step 1: Create the worktree skill**

Create `harnesskit/skills/worktree.md`:

```markdown
---
name: worktree
description: Create a harness-aware git worktree for isolated feature work using Claude Code's built-in worktree
user_invocable: true
---

# /harnesskit:worktree

Create an isolated worktree for a specific feature, syncing harness files for session continuity.

## Usage

```
/harnesskit:worktree feat-007
```

Takes a feature ID from `docs/feature_list.json`.

## Prerequisites

- `.harnesskit/config.json` must exist (HarnessKit initialized)
- `docs/feature_list.json` must contain the specified feature ID

## Instructions — Enter

1. Validate the feature ID exists in `docs/feature_list.json`
   - If not found: "Feature '{id}' not found in feature_list.json. Available: {list ids}"

2. Invoke Claude Code's built-in worktree creation (use EnterWorktree tool)

3. Sync harness files to the new worktree (only non-git-tracked files):
   - Copy `.harnesskit/` directory (config.json, detected.json, failures.json, insights-history.json, session-logs/)
   - ※ CLAUDE.md, .claudeignore, docs/feature_list.json, progress/ are git-tracked — already in worktree

4. Set `.harnesskit/current-feature.txt` to the specified feature ID

5. Output:
   ```
   🌲 Worktree ready for {feature_id}: {feature_description}
      Harness files synced.

      When done, sync data back before exiting:
      1. Copy .harnesskit/session-logs/*.json back to main
      2. Merge .harnesskit/failures.json with main (new failures: add, existing: sum occurrences)
      3. Update docs/feature_list.json passes field if feature completed
      4. Use ExitWorktree to return
   ```

## Instructions — Exit (Data Sync)

Before calling ExitWorktree, sync harness data back to main:

1. **Session logs**: Copy `.harnesskit/session-logs/*.json` from worktree to main's `.harnesskit/session-logs/` (append, no overwrite — filenames are timestamp-based)

2. **Failures**: Merge `.harnesskit/failures.json`:
   - New failures (pattern not in main): add to main
   - Existing failures (same pattern): sum occurrences, update lastSeen

3. **Current session**: Move `.harnesskit/current-session.jsonl` to main if exists

4. **Feature list**: For any feature where `passes` changed from `false` to `true`, update main's `docs/feature_list.json` (one-way: only false→true)

5. **Progress**: Append worktree's `progress/claude-progress.txt` content to main's progress file

6. Output: "✅ Harness data synced to main. Exiting worktree."

7. Call ExitWorktree
```

- [ ] **Step 2: Commit**

```bash
git add harnesskit/skills/worktree.md
git commit -m "feat(v2b): add /harnesskit:worktree skill — harness-aware worktree isolation"
```

---

### Task 5: apply.md — A/B Eval Comparison

**Files:**
- Modify: `harnesskit/skills/apply.md`

- [ ] **Step 1: Read current apply.md**

- [ ] **Step 2: Add A/B eval prompt**

After the existing "Process user response" section item 3 (the y/n/edit handling), insert the following. Find the line with `- For skill customization (type=skill_customization)` and `- For skill creation (type=skill_creation)` — add the eval prompt **between** the user saying "y" and the actual execution:

Add this block right after `- **y (yes)**: Apply the change` and before the first `- For skill customization` line:

```markdown
     - **A/B Eval (skill proposals only)**: For `skill_customization` or `skill_creation` proposals, after user approves (y):
       1. Check if `/skill-builder` is installed
          - If not installed: skip eval, proceed directly to execution. Show: "💡 Install /skill-builder for A/B eval comparison"
       2. If installed, prompt: "🔬 Run eval comparison? (y/n) — Compares current state (baseline) vs proposed skill"
       3. If user says n: proceed directly to execution
       4. If user says y:
          a. Baseline: `/skill-builder` runs eval with current state (existing plugin or no skill)
          b. Generate proposed skill via `/skill-builder`
          c. Run eval with proposed skill
          d. Show comparison:
             ```
             Baseline (current):     score X/10
             With proposed skill:    score Y/10 (+Z improvement)
             ```
          e. User confirms: apply / skip
          f. Record eval results in insights-history.json proposal entry:
             `"eval": {"baseline": X, "proposed": Y, "delta": Z, "ranAt": "{date}"}`
```

- [ ] **Step 3: Commit**

```bash
git add harnesskit/skills/apply.md
git commit -m "feat(v2b): add A/B eval comparison prompt to apply for skill proposals"
```

---

### Task 6: insights.md — Worktree Suggestion + Bible Citation

**Files:**
- Modify: `harnesskit/skills/insights.md`

- [ ] **Step 1: Read current insights.md**

Find the "### 2. Feature Progress" section (around line 33).

- [ ] **Step 2: Add worktree suggestion**

Append to the Feature Progress dimension:

```markdown
- Feature switching detection: if `current-feature.txt` changed multiple times in a session (visible in session-logs), suggest worktree isolation
  → "feat-003과 feat-005 사이를 {N}회 전환했습니다. /harnesskit:worktree를 사용하여 격리 작업을 고려해보세요."
  ※ This is a nudge in the report output, not a separate proposal type
```

- [ ] **Step 3: Add bible citation guidance**

Find the "## Proposal Generation" section. In the proposal template (the `Reason:` line), add guidance:

```markdown
### Bible Citation (v2b)

When generating proposal reasons, reference `.harnesskit/bible.md` principles where applicable:
- Read `.harnesskit/bible.md` if it exists
- When a proposal aligns with a bible principle, cite it in the Reason field:
  "바이블 원칙 '{section}: {principle}'에 따라, {recommendation}"
- Bible citation is optional context — proposals are valid without it
- Bible is reference only, not a directive source
```

- [ ] **Step 4: Commit**

```bash
git add harnesskit/skills/insights.md
git commit -m "feat(v2b): add worktree suggestion + bible citation guidance to insights"
```

---

### Task 7: plugin.json — Register New Skills + Version Bump

**Files:**
- Modify: `harnesskit/plugin.json`

- [ ] **Step 1: Update plugin.json**

Replace the entire content of `harnesskit/plugin.json` with:

```json
{
  "name": "harnesskit",
  "version": "0.2.0",
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
    "skills/dev.md",
    "skills/prd.md",
    "skills/worktree.md"
  ],
  "agents": [
    "agents/orchestrator.md"
  ]
}
```

Changes: version 0.1.0 → 0.2.0, added `skills/prd.md` and `skills/worktree.md`.

- [ ] **Step 2: Commit**

```bash
git add harnesskit/plugin.json
git commit -m "feat(v2b): register prd + worktree skills, bump version to 0.2.0"
```

---

### Task 8: Run All Tests + E2E Verification

**Files:**
- All test files + new skill files

- [ ] **Step 1: Run all existing tests**

```bash
for t in harnesskit/tests/test-*.sh; do echo "--- $t ---"; bash "$t" 2>&1 | tail -2; echo ""; done
```

Expected: All 89 tests pass (73 v1 + 16 v2a). No regressions.

- [ ] **Step 2: Verify all skill files have valid frontmatter**

```bash
for f in harnesskit/skills/*.md; do
  if head -1 "$f" | grep -q "^---"; then
    echo "✅ $f"
  else
    echo "❌ $f missing frontmatter"
  fi
done
```

Expected: All 11 skills pass (9 existing + prd.md + worktree.md).

- [ ] **Step 3: Verify plugin.json references valid files**

```bash
jq -r '.skills[]' harnesskit/plugin.json | while read skill; do
  if [ -f "harnesskit/$skill" ]; then
    echo "✅ $skill"
  else
    echo "❌ $skill NOT FOUND"
  fi
done
jq -r '.agents[]' harnesskit/plugin.json | while read agent; do
  if [ -f "harnesskit/$agent" ]; then
    echo "✅ $agent"
  else
    echo "❌ $agent NOT FOUND"
  fi
done
```

Expected: All 11 skills + 1 agent exist.

- [ ] **Step 4: Verify bible template exists and is non-empty**

```bash
if [ -f "harnesskit/templates/bible.md" ] && [ -s "harnesskit/templates/bible.md" ]; then
  LINES=$(wc -l < harnesskit/templates/bible.md)
  echo "✅ bible.md exists ($LINES lines)"
else
  echo "❌ bible.md missing or empty"
fi
```

- [ ] **Step 5: Verify plugin.json version and structure**

```bash
VERSION=$(jq -r '.version' harnesskit/plugin.json)
SKILL_COUNT=$(jq '.skills | length' harnesskit/plugin.json)
echo "Version: $VERSION (expected: 0.2.0)"
echo "Skills: $SKILL_COUNT (expected: 11)"
```

---

## Summary

After completing this plan, you have:
- ✅ `bible.md` — curated harness engineering principles (constant template, not user-modifiable)
- ✅ `prd.md` — `/harnesskit:prd` decomposes PRDs into GitHub issues + feature_list
- ✅ `worktree.md` — `/harnesskit:worktree` creates harness-aware isolated worktrees
- ✅ `apply.md` updated with A/B eval comparison for skill proposals
- ✅ `init.md` updated with bible copy step + schema 2.1
- ✅ `insights.md` updated with worktree suggestion in Feature Progress
- ✅ `plugin.json` updated: version 0.2.0, 11 skills registered
- ✅ All 89 existing tests pass (no regressions)

**Next:** Real-world testing on an actual project, or push to GitHub for distribution
