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
