---
name: imgen-api-first
description: Use for any work in the imgen project, especially image_requests, prompt_projects, generated images, prompt runs, browser-like actions, and requests that mention the web UI. Always read this skill before acting in this repository.
---

# Imgen API-First Workflow

## Core Rule

Before any action in `/home/feda/imgen`, read this skill and follow it.

Respond to the user in Russian unless the user explicitly asks for another language.

## Web Requests Must Use API

If the user asks to do something through the web version, browser page, UI, or a URL such as `/image_requests#request-21`, perform the same action through the API surface instead.

Use the web UI only for visual verification when the user explicitly needs to see layout, styles, screenshots, or browser-only behavior.

## Required Product Shape

The project has a human web interface and must also have an agent-friendly API with equivalent capabilities.

For every user-facing action available in the web UI, prefer or add an API endpoint that can do the same thing with structured request/response data.

API responses should be JSON and include stable IDs, statuses, generated image URLs, errors, and next actionable URLs where useful.

## UI And API Parity

When changing any user-facing interface behavior, check whether the API must change too.

Every UI capability must have an equivalent API capability for agent use. This includes create, retry, regenerate, delete, inspect, list, status polling, model selection, feedback, and any future workflow action.

Do not implement business behavior only in views, helpers, HTML controllers, or JavaScript. Put shared behavior in application/service classes and call those classes from both the human UI and the API.

When adding or changing a UI action, update these surfaces together:

- shared service object or operation class;
- HTML controller/view behavior;
- API endpoint and serializer/response contract;
- API request specs and, when present, OpenAPI documentation.

If the API does not yet exist for a UI action, treat API creation as part of the same feature unless the user explicitly asks for UI-only work.

## Current Main Domain

The primary workflow is image generation:

- list recent image requests;
- create an image request;
- inspect one image request;
- retry an image request;
- delete an image request;
- list available models;
- regenerate one result image;
- delete one result image;
- fetch generated image files.

Prompt-project workflows should follow the same rule:

- list/create/show prompt projects;
- run a prompt revision;
- inspect prompt runs and feedback;
- fetch prompt-run images.

## Implementation Preference

Prefer explicit Rails JSON endpoints under `/api/v1` rather than scraping HTML or driving the browser.

Keep existing HTML controllers working. Either:

- add parallel API controllers under `Api::V1`, or
- extract shared application operations into service objects and call them from both HTML and API controllers.

For non-trivial actions, prefer shared service objects so web and API behavior cannot drift.

Do not add Grape unless the project later needs a separate API DSL for a much larger standalone API surface. For this Rails MVC app, use ordinary Rails controllers first.

## API Documentation Preference

Use OpenAPI/Swagger documentation for the agent-facing API contract once API endpoints are added.

Prefer `rswag` because it can keep request specs and OpenAPI documentation close together. The goal is not documentation for humans only; the goal is a machine-readable contract that lets an agent understand which actions exist, what parameters they accept, and what JSON shape they return.

Keep the OpenAPI contract aligned with request specs. Do not maintain a stale manual API document separately from tested behavior.

## Response Contract Preference

Use a consistent envelope for API actions:

```json
{
  "ok": true,
  "data": {},
  "error": null
}
```

For failures:

```json
{
  "ok": false,
  "data": null,
  "error": {"message": "human-readable error"}
}
```

## Operating Rule For Agents

When acting on a specific UI URL, map it to the corresponding API operation first.

Example: `/image_requests#request-21` means inspect or manipulate `ImageRequest` id `21` via API/JSON, not browser automation.

When a user asks for a UI change, first identify the matching API operation. If none exists, add it or include it in the implementation plan before changing the UI.
