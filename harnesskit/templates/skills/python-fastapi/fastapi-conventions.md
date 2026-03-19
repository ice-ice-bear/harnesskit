---
name: fastapi-conventions
description: FastAPI endpoint patterns, Pydantic schemas, and response format standards
---

# FastAPI Conventions

## Endpoint Structure
- Async by default: `async def endpoint()`
- Group related endpoints in routers
- Use dependency injection for shared logic

## Schemas
- Pydantic v2 BaseModel for all request/response schemas
- Always specify `response_model` on endpoints
- Standard response: `{"success": true, "data": {...}}`
- Error response: `{"success": false, "error": {"code": "...", "message": "..."}}`

## Error Handling
- Custom AppException for business logic errors
- HTTPException for HTTP-level errors only
