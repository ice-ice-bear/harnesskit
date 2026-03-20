<div align="center">

# HarnessKit

**Adaptive harness for vibe coders — detect, configure, observe, improve**

[![Version](https://img.shields.io/badge/version-0.2.0-blue)]()
[![Tests](https://img.shields.io/badge/tests-89%20passing-green)]()
[![License](https://img.shields.io/badge/license-MIT-yellow)]()

[한국어](README.ko.md) | English

</div>

---

## Overview

HarnessKit is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that wraps your development workflow in an adaptive harness. It detects your stack, applies guardrails matched to your skill level, observes your sessions, and continuously improves itself — all without wasting context tokens.

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

## Features

| Stage | What it does | How |
|-------|-------------|-----|
| **Detect** | Auto-detects repo language, framework, test framework, linter, package manager | Zero-token shell script — no LLM calls |
| **Configure** | Applies one of 3 presets (beginner / intermediate / advanced) | Controls guardrails depth, briefing detail, dev hooks |
| **Observe** | Tracks errors, tool usage, plugin effectiveness per session | Shell-based hooks (session-start, guardrails, session-end) |
| **Improve** | Analyzes session data, proposes skill/agent/hook/rule improvements | `/harnesskit:insights` analyzes, `/harnesskit:apply` executes |

## Install

```bash
/plugin marketplace add ice-ice-bear/harnesskit
/plugin install harnesskit@harnesskit
```

## Quick Start

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

## Commands

HarnessKit provides 11 skills, accessible as slash commands:

| Command | Description |
|---------|-------------|
| `/harnesskit:setup` | Initialize harness — detect stack, choose preset, generate config |
| `/harnesskit:insights` | Analyze session data, propose improvements |
| `/harnesskit:apply` | Review and apply proposals (with optional A/B eval) |
| `/harnesskit:status` | Dashboard showing harness state, metrics, coverage |
| `/harnesskit:test` | Run tests with failure tracking and error classification |
| `/harnesskit:lint` | Run configured linter |
| `/harnesskit:typecheck` | Run TypeScript type checking |
| `/harnesskit:dev` | Start dev server |
| `/harnesskit:prd` | Decompose PRD into GitHub issues + feature list |
| `/harnesskit:worktree` | Harness-aware git worktree for isolated feature work |

> **Note**: `setup` internally calls `init` which handles detection and file generation. The 11th skill (`init`) runs as part of setup and is not called directly.

## Presets

Choose a preset during `/harnesskit:setup` based on your comfort level:

| | Beginner | Intermediate | Advanced |
|---|---|---|---|
| **Guardrails** | Strict — confirms before destructive ops, enforces test-before-commit | Moderate — warnings only, skip confirmation for safe ops | Minimal — trust the developer |
| **Briefing** | Detailed — explains what each hook does | Standard — concise summaries | Silent — no briefing unless errors |
| **Session hooks** | All enabled + verbose logging | All enabled, compact logging | Selective — only error tracking |
| **Auto-apply** | Off — always ask before changes | Suggest — show diff, one-click apply | Auto — apply low-risk improvements automatically |
| **Best for** | New to AI-assisted coding | Regular Claude Code users | Power users, vibe coders |

## Architecture

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
HarnessKit/
├── .claude-plugin/
│   ├── plugin.json        # Plugin manifest (v0.2.0)
│   └── marketplace.json   # Marketplace catalog
├── skills/                # 11 skill definitions
├── agents/                # Orchestrator agent
├── hooks/                 # Session hooks (bash + jq)
├── scripts/               # Detection & utility scripts
├── templates/             # Config templates, presets, bible
├── tests/                 # 89 tests across 8 suites
├── docs/                  # Design specs, plans, research
├── README.md
├── README.ko.md
└── LICENSE
```

## Generated Files

When you run `/harnesskit:setup`, HarnessKit generates these files in your project:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Session protocol + framework conventions (composed from templates) |
| `.claudeignore` | Context exclusion patterns per language |
| `.claude/settings.json` | Hook registrations (session-start, guardrails, session-end) |
| `docs/feature_list.json` | Feature tracking (`passes: false` pattern) |
| `progress/claude-progress.txt` | Session-to-session work continuity |
| `.harnesskit/config.json` | Preset, schema version, installed plugins, custom toolkit |
| `.harnesskit/detected.json` | Auto-detected repo properties |
| `.harnesskit/failures.json` | Error pattern tracking across sessions |
| `.harnesskit/session-logs/` | Per-session observation data (tool usage, time distribution) |
| `.harnesskit/bible.md` | Curated harness engineering principles reference |

All generated files respect your chosen preset.

## How the Improve Loop Works

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

## Contributing

Contributions are welcome.

```bash
# Clone
git clone https://github.com/ice-ice-bear/harnesskit.git
cd harnesskit

# Run all tests (89 tests across 8 suites)
for t in tests/test-*.sh; do bash "$t"; done
```

Please open an issue before submitting large changes.

## License

[MIT](LICENSE) — Copyright 2026 HarnessKit Contributors
