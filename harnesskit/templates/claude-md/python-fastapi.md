## FastAPI Conventions
- Async endpoints by default
- Pydantic v2 for all schemas with `response_model`
- Standard response: `{"success": true, "data": {...}}`
- Error response: `{"success": false, "error": {"code": "...", "message": "..."}}`

## Skills Reference
- FastAPI conventions → .harnesskit/skills/fastapi-conventions.md
- Testing patterns → .harnesskit/skills/fastapi-testing.md

## Test Command
- `pytest -v`
