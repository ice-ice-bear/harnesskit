<div align="center">

# HarnessKit

**Adaptive harness for vibe coders — detect, configure, observe, improve**

바이브 코더를 위한 적응형 하네스 — 감지, 설정, 관찰, 개선

[![Version](https://img.shields.io/badge/version-0.2.0-blue)]()
[![Tests](https://img.shields.io/badge/tests-89%20passing-green)]()
[![License](https://img.shields.io/badge/license-MIT-yellow)]()

</div>

---

## Overview / 개요

HarnessKit is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that wraps your development workflow in an adaptive harness. It detects your stack, applies guardrails matched to your skill level, observes your sessions, and continuously improves itself — all without wasting context tokens.

HarnessKit은 Claude Code 플러그인으로, 개발 워크플로를 적응형 하네스로 감싸줍니다. 스택을 자동 감지하고, 숙련도에 맞는 가드레일을 적용하며, 세션을 관찰하고, 스스로를 지속적으로 개선합니다.

```
┌─────────────────────────────────────────────────┐
│                  HarnessKit                      │
│                                                  │
│   Detect ──▶ Configure ──▶ Observe ──▶ Improve   │
│     │           │             │           │      │
│  language    presets      session       insights  │
│  framework   guardrails   hooks        proposals  │
│  tooling     briefing     metrics      auto-apply │
│                                                  │
│          Zero-Token Shell Hooks                  │
│          ── bash + jq, no LLM cost ──            │
└─────────────────────────────────────────────────┘
```

## Features / 주요 기능

| Stage | What it does | How |
|-------|-------------|-----|
| **Detect** / 감지 | Auto-detects repo language, framework, test framework, linter, package manager | Zero-token shell script — no LLM calls |
| **Configure** / 설정 | Applies one of 3 presets (beginner / intermediate / advanced) | Controls guardrails depth, briefing detail, dev hooks |
| **Observe** / 관찰 | Tracks errors, tool usage, plugin effectiveness per session | Shell-based hooks (session-start, guardrails, session-end) |
| **Improve** / 개선 | Analyzes session data, proposes skill/agent/hook/rule improvements | `/harnesskit:insights` analyzes, `/harnesskit:apply` executes |

## Install / 설치

```bash
claude plugin install harnesskit
```

## Quick Start / 빠른 시작

```bash
# 1. Initialize harness for your repo
/harnesskit:setup

# 2. Code normally — hooks observe your session automatically

# 3. After a few sessions, review insights
/harnesskit:insights

# 4. Apply recommended improvements
/harnesskit:apply
```

That's it. HarnessKit adapts to your workflow over time.

## Commands / 명령어 참조

HarnessKit provides 11 skills, accessible as slash commands:

| Command | Description | 설명 |
|---------|-------------|------|
| `/harnesskit:setup` | Initialize harness — detect stack, choose preset, generate config | 하네스 초기화 — 스택 감지, 프리셋 선택, 설정 생성 |
| `/harnesskit:insights` | Analyze session data, propose improvements | 세션 데이터 분석, 개선안 제안 |
| `/harnesskit:apply` | Review and apply proposals (with optional A/B eval) | 제안 검토 및 적용 (A/B 평가 옵션) |
| `/harnesskit:status` | Dashboard showing harness state, metrics, coverage | 하네스 상태 대시보드 |
| `/harnesskit:test` | Run tests with failure tracking and error classification | 테스트 실행 + 실패 추적 |
| `/harnesskit:lint` | Run configured linter | 린터 실행 |
| `/harnesskit:typecheck` | Run TypeScript type checking | TypeScript 타입 체크 |
| `/harnesskit:dev` | Start dev server | 개발 서버 시작 |
| `/harnesskit:prd` | Decompose PRD into GitHub issues + feature list | PRD를 GitHub 이슈 + 기능 목록으로 분해 |
| `/harnesskit:worktree` | Harness-aware git worktree for isolated feature work | 하네스 인식 워크트리로 기능별 격리 작업 |

> **Note**: `setup` internally calls `init` which handles detection and file generation. The 11th skill (`init`) runs as part of setup and is not called directly.

## Presets / 프리셋

Choose a preset during `/harnesskit:setup` based on your comfort level:

| | Beginner / 초급 | Intermediate / 중급 | Advanced / 고급 |
|---|---|---|---|
| **Guardrails** | Strict — confirms before destructive ops, enforces test-before-commit | Moderate — warnings only, skip confirmation for safe ops | Minimal — trust the developer |
| **Briefing** | Detailed — explains what each hook does | Standard — concise summaries | Silent — no briefing unless errors |
| **Session hooks** | All enabled + verbose logging | All enabled, compact logging | Selective — only error tracking |
| **Auto-apply** | Off — always ask before changes | Suggest — show diff, one-click apply | Auto — apply low-risk improvements automatically |
| **Best for** | New to AI-assisted coding | Regular Claude Code users | Power users, vibe coders |

## Architecture / 아키텍처

### Design Principles

- **Marketplace First**: Uses existing Claude Code plugins before creating custom tools. Only customizes when session data shows a gap.
- **Zero-Token Hooks**: All observation hooks (`session-start`, `guardrails`, `session-end`) run as bash + jq scripts. They cost zero LLM tokens.
- **Bible**: A curated set of harness engineering principles, referenced by all skills for consistency.

### Subsystems

| Subsystem | Purpose |
|-----------|---------|
| **v2a** — Adaptive Generation | Auto-generates skills, agents, hooks, and rules from session data. Powers the `insights` → `apply` loop. |
| **v2b** — Advanced Workflows | A/B testing for proposals, PRD decomposition into issues, harness-aware worktree isolation. |

### Plugin Structure

```
harnesskit/
├── plugin.json          # Plugin manifest
├── skills/              # 11 skill definitions (setup, insights, apply, ...)
├── agents/              # Orchestrator agent
├── hooks/               # Session hooks (bash + jq)
├── scripts/             # Detection & utility scripts
├── templates/           # Config templates per preset
└── tests/               # Plugin tests
```

## Generated Files / 생성 파일

When you run `/harnesskit:setup`, HarnessKit generates files in your project's `.claude/` directory:

| File | Purpose |
|------|---------|
| `.claude/settings.json` | Claude Code settings with harness overrides |
| `.claude/harnesskit.json` | Harness config — preset, detected stack, feature flags |
| `.claude/hooks/session-start.sh` | Pre-session hook — loads context, checks environment |
| `.claude/hooks/session-end.sh` | Post-session hook — logs metrics, detects patterns |
| `.claude/hooks/guardrails.sh` | Guardrail hook — enforces preset rules |
| `.claude/data/sessions/` | Session observation logs (gitignored) |
| `.claude/data/proposals/` | Improvement proposals from insights |

All generated files respect your chosen preset. Data files are automatically added to `.gitignore`.

## How the Improve Loop Works / 개선 루프

```
Sessions accumulate data
        │
        ▼
/harnesskit:insights
  ├── Analyzes: errors, tool usage, time sinks, coverage gaps
  ├── Proposes: new skills, agents, hooks, rules, or config changes
  └── Categorizes: skill_creation, hook_creation, review_supplement, ...
        │
        ▼
/harnesskit:apply
  ├── Shows each proposal with diff preview
  ├── Options: accept / reject / A/B test
  └── Executes: generates files, updates config
        │
        ▼
Next sessions benefit from improvements
```

## Contributing / 기여

Contributions are welcome.

```bash
# Clone
git clone https://github.com/your-org/HarnessKit.git
cd HarnessKit

# Run tests
cd harnesskit && ./tests/run.sh

# Structure
# - Skills go in harnesskit/skills/
# - Hooks go in harnesskit/hooks/
# - Scripts go in harnesskit/scripts/
```

Please open an issue before submitting large changes.

## License / 라이선스

[MIT](LICENSE) — Copyright 2026 HarnessKit Contributors
