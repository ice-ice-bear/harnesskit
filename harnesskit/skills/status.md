---
name: status
description: Show current HarnessKit harness status — preset, feature progress, active failures, installed toolkit
user_invocable: true
---

# /harnesskit:status

Display a quick dashboard of the current harness state. Read files only, no modifications.

## Instructions

1. Read `.harnesskit/config.json` for preset and detection date
2. Read `.harnesskit/detected.json` for project type
3. Read `docs/feature_list.json` for feature progress
4. Read `.harnesskit/failures.json` for active failures
5. Read `.harnesskit/insights-history.json` for last insights date
6. List `.harnesskit/skills/` for installed skills
7. List `.harnesskit/agents/` for installed agents

Output format:

```
═══ HarnessKit Status ═══

⚙️  Preset: {preset} (since {detectedAt})
📂  Project: {framework} + {language} + {testFramework}

📋  Features:
    {progress bar} {done}/{total} ({percentage}%)

🛠  Toolkit:
    Skills: {list of .harnesskit/skills/*.md names}
    Agents: {list of .harnesskit/agents/*.md names}
    Dev Hooks: {list active hooks from .claude/settings.json}

⚠️  Active Failures: {count}
    {list top 3 open failures with pattern and occurrences}

💡  Last Insights: {date or "never"}

══════════════════════════
```

If `.harnesskit/config.json` does not exist, output:
```
HarnessKit is not initialized. Run /harnesskit:setup first.
```
