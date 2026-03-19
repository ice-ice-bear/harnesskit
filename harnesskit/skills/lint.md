---
name: lint
description: Run linter and formatter for the project with auto-fix — integrates with HarnessKit error tracking
user_invocable: true
---

# /harnesskit:lint

Run the project's linter and formatter.

1. Read `.harnesskit/detected.json` to determine linter
2. Run linter with auto-fix:
   - eslint: `npx eslint . --fix`
   - ruff: `ruff check --fix . && ruff format .`
   - biome: `npx biome check --apply .`
   - flake8: `flake8 .`
3. Report results (files fixed, remaining issues)
4. If errors persist, append to `.harnesskit/current-session.jsonl`
