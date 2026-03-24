---
name: setup
description: Detect project tech stack, choose experience preset, and initialize HarnessKit harness + toolkit
user_invocable: true
---

# /harnesskit:setup

You are the HarnessKit setup assistant. Your job is to detect the project's tech stack, help the user choose an experience preset, and initialize the harness infrastructure and toolkit.

## Step 1: Detect Project

Run the detection script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect-repo.sh" "$(pwd)"
```

Parse the JSON output and present results to the user:

```
🔍 Project Detection Results:
  Language:        {language}
  Framework:       {framework}
  Package Manager: {packageManager}
  Test Framework:  {testFramework}
  Linter:          {linter}
  Monorepo:        {monorepo}
  Git:             {git}
```

If existing harness files are detected, present options:
- (1) Merge — keep existing files, only create missing ones
- (2) Overwrite — regenerate all (backup existing to .harnesskit/backup/)
- (3) Cancel

## Step 2: Choose Preset

Present preset options:

```
Choose your experience level:

  (1) 🟢 Beginner — Strong guardrails, step-by-step guidance, maximum protection
  (2) 🟡 Intermediate — Balanced guardrails, concise guidance, moderate autonomy
  (3) 🔴 Advanced — Minimal guardrails, no guidance, maximum autonomy
```

Wait for user selection.

## Step 3: Save Detection + Config

Create `.harnesskit/` directory and save:

1. `.harnesskit/detected.json` — the detection script output
2. `.harnesskit/config.json` — with structure:

```json
{
  "schemaVersion": "1.0.0",
  "preset": "{selected_preset}",
  "detectedAt": "{ISO timestamp}",
  "installedPlugins": [],
  "overrides": {}
}
```

## Step 4: Hand off to Init

After saving config, invoke the orchestrator agent to proceed with file generation (init.md) and toolkit setup.

If init.md is not yet available, output:

```
✅ Detection and preset saved.
   .harnesskit/detected.json
   .harnesskit/config.json

⏳ File generation will be available after /harnesskit:init is implemented.
```

## Reset Mode (/harnesskit:reset)

When invoked as `/harnesskit:reset`:

1. Show current preset from `.harnesskit/config.json`
2. Ask user to select new preset (or keep same)
3. **Preserved files** (never deleted):
   - `.harnesskit/failures.json`
   - `.harnesskit/session-logs/`
   - `.harnesskit/insights-history.json`
   - `docs/feature_list.json`
4. **Backed up then regenerated**:
   - `CLAUDE.md` → `.harnesskit/backup/CLAUDE.md.{timestamp}`
   - `.claudeignore` → `.harnesskit/backup/`
5. **Regenerated**:
   - `.harnesskit/config.json` (new preset)
   - `.harnesskit/detected.json` (re-run detection)
   - `CLAUDE.md` (new preset + re-detection)
   - `.claudeignore` (re-detection)
6. Re-run toolkit generation (skills, hooks, agents) with new preset

### --full flag

`/harnesskit:reset --full`:
1. Confirm with user: "This will delete all HarnessKit data. Continue? (y/n)"
2. Delete entire `.harnesskit/` directory
3. Remove harnesskit hooks from `.claude/settings.json`
4. Output: "HarnessKit fully removed. Run /harnesskit:setup to re-initialize."
