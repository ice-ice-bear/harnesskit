---
description: Run TypeScript type checker and summarize errors — only available for TypeScript projects
user_invocable: true
---

# /harnesskit:typecheck

Run TypeScript type checking.

1. Verify project uses TypeScript (check `.harnesskit/detected.json`)
2. If not TypeScript: "This project does not use TypeScript."
3. Run: `npx tsc --noEmit`
4. Summarize errors by file
5. Append type errors to `.harnesskit/current-session.jsonl`
