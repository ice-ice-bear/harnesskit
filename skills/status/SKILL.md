---
name: status
description: Show current HarnessKit harness status — preset, feature progress, active failures, installed toolkit
user_invocable: true
---

# /harnesskit:status

Display a quick dashboard of the current harness state. Read files only, no modifications.

## Instructions

1. Read `.harnesskit/config.json` for preset, schemaVersion, installedPlugins, uncoveredAreas, reviewInternalization, customSkills, customAgents, customHooks

## Plugin Installation Verification

After reading installedPlugins from config.json:

1. Check if `$HOME/.claude/plugins/cache/` directory exists
2. If it exists, for each plugin in installedPlugins:
   - Use glob search: `find $HOME/.claude/plugins/cache/ -maxdepth 2 -name "{plugin-name}" -type d`
   - Cache path may vary by Claude Code version — name-based glob is safest
3. Report status per plugin:
   - ✅ {name} — installed and cached
   - ⚠️ {name} — in config but not found in cache (may need reinstall)
   - If glob search fails or returns unexpected results, fall back to "unverified"

If cache directory doesn't exist, skip verification and display config as-is with note:
  "(plugin cache not found — verification skipped)"

If installedPlugins is empty, display:
  "Marketplace Plugins: none installed"

If mismatches found, suggest:
  "Run `/plugin install {name}@claude-plugins-official` to reinstall missing plugins,
   or update .harnesskit/config.json to remove stale entries."

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
    Marketplace Plugins:
      ✅ {name} — installed (for verified plugins)
      ⚠️ {name} — not found in cache (for unverified)
      (or "none installed" if empty)
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
