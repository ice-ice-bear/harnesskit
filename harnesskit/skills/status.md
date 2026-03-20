---
name: status
description: Show current HarnessKit harness status — preset, feature progress, active failures, installed toolkit
user_invocable: true
---

# /harnesskit:status

Display a quick dashboard of the current harness state. Read files only, no modifications.

## Instructions

1. Read `.harnesskit/config.json` for preset, schemaVersion, installedPlugins, uncoveredAreas, reviewInternalization, customSkills, customAgents, customHooks
2. Read `.harnesskit/detected.json` for project type
3. Read `docs/feature_list.json` for feature progress
4. Read `.harnesskit/failures.json` for active failures
5. Read `.harnesskit/insights-history.json` for last insights date

Output format:

```
═══ HarnessKit Status ═══

⚙️  Preset: {preset} (since {detectedAt})
    Schema: v{schemaVersion}
📂  Project: {framework} + {language} + {testFramework}

📋  Features:
    {progress bar} {done}/{total} ({percentage}%)

🛠  Toolkit:
    Marketplace Plugins: {list from config.json installedPlugins}
    Custom Skills: {list from config.json customSkills, or "none yet"}
    Custom Agents: {list from config.json customAgents, or "none yet"}
    Custom Hooks: {list from config.json customHooks, or "none yet"}
    Dev Hooks: {list active hooks from .claude/settings.json}

🔍  Review Internalization: {stage} {coveragePercent if supplement/replace}
    Uncovered Areas: {list from config.json uncoveredAreas, or "all covered"}

⚠️  Active Failures: {count}
    {list top 3 open failures with pattern and occurrences}

💡  Last Insights: {date or "never"}

══════════════════════════
```

If `.harnesskit/config.json` does not exist, output:
```
HarnessKit is not initialized. Run /harnesskit:setup first.
```
