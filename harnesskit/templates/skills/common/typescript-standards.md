---
name: typescript-standards
description: TypeScript type conventions, strict mode rules, and type-safe patterns
---

# TypeScript Standards

## Strict Mode
- `strict: true` in tsconfig.json
- No `any` — use `unknown` and narrow

## Types
- Prefer `interface` for object shapes, `type` for unions/intersections
- Export types alongside their implementations
- Use branded types for domain identifiers

## Imports
- Use path aliases (`@/`) for project imports
- Sort: external → internal → relative
