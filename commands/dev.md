---
description: Start the development server for the detected framework — auto-configured based on project detection
user_invocable: true
---

# /harnesskit:dev

Start the project's development server.

1. Read `.harnesskit/detected.json` to determine framework
2. Start dev server:
   - nextjs: `npx next dev`
   - vite/react-vite: `npx vite`
   - fastapi: `uvicorn main:app --reload`
   - django: `python manage.py runserver`
   - unknown: Ask user for the dev command
3. Report the URL where the server is accessible
