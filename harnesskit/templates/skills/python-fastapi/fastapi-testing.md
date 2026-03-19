---
name: fastapi-testing
description: Testing patterns for FastAPI projects using pytest and httpx
---

# FastAPI Testing Patterns

## Test Client
- Use `httpx.AsyncClient` with `app` for async tests
- Use `TestClient` from Starlette for sync tests

## Database
- Use test database with fixtures
- Rollback transactions after each test

## Naming
- `test_*.py` files in `tests/` directory
- Function names: `test_{endpoint}_{scenario}`
