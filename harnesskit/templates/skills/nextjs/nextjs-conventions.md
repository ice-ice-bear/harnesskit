---
name: nextjs-conventions
description: Next.js App Router conventions, Server/Client Component rules, and routing patterns for this project
---

# Next.js Conventions

## Component Model
- Default to Server Components
- Add `'use client'` only for: event handlers, useState/useEffect, browser APIs
- Colocate client components in the same directory as their server parent

## Routing
- App Router with file-based routing
- Dynamic routes: `[param]` directories
- Route groups: `(group)` for layout organization

## Data Fetching
- Server Components: direct async/await (no useEffect)
- Client Components: SWR or React Query
- Server Actions for mutations

## Images & Assets
- Always use `next/image` with width/height or fill
- SVGs: import as React components or use `next/image`
