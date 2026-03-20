# Privacy Policy

**HarnessKit** — Claude Code Plugin

Last updated: 2026-03-20

## Data Collection

HarnessKit **does not collect, transmit, or store any data externally**. All data remains on your local machine within your project directory.

## What HarnessKit Stores Locally

The following files are created in your project's `.harnesskit/` directory:

| File | Content | Purpose |
|------|---------|---------|
| `config.json` | Preset selection, detected stack | Plugin configuration |
| `detected.json` | Language, framework, linter info | Auto-detection results |
| `failures.json` | Error patterns from sessions | Failure tracking |
| `session-logs/*.json` | Tool usage, time distribution per session | Session observation |
| `bible.md` | Harness engineering principles | Reference document |

## Network Access

- HarnessKit makes **no network requests** on its own
- The `/harnesskit:prd` command uses GitHub MCP (if available) to create issues — this is user-initiated and goes through Claude Code's existing GitHub integration
- The `/harnesskit:worktree` command uses Claude Code's built-in worktree feature — no external calls

## Third-Party Services

HarnessKit does not integrate with any third-party analytics, telemetry, or tracking services.

## Shell Hooks

HarnessKit registers shell hooks (bash scripts) that run locally during Claude Code sessions. These hooks:
- Read/write only to `.harnesskit/` and `.claude/` directories in your project
- Execute `bash` and `jq` commands only
- Consume zero LLM tokens (no API calls)

## Data Retention

All data is stored as plain JSON/text files in your project. Delete `.harnesskit/` to remove all HarnessKit data. No data persists outside your project directory.

## Contact

For privacy questions, open an issue at: https://github.com/ice-ice-bear/harnesskit/issues

## Changes

This policy may be updated with new plugin versions. Changes will be noted in release notes.
