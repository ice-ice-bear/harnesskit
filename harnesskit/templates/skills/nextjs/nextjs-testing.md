---
name: nextjs-testing
description: Testing patterns for Next.js projects using Vitest and React Testing Library
---

# Next.js Testing Patterns

## Unit Tests
- Use Vitest + React Testing Library
- Test components in isolation with mock providers
- Test Server Components by importing directly

## Integration Tests
- Test page-level components with mocked API routes
- Use MSW for API mocking

## Naming
- `*.test.tsx` colocated with component files
- Describe blocks match component name
