# Xvideo Web Agent Workflow

This repository's active branch target is a Web application for Xvideo. These instructions are project-local working agreements for Web development, documentation, verification, packaging, and release work.

Follow this workflow for repository changes unless the user explicitly asks to skip or revise it. When the user asks to revise the workflow itself, treat that as documentation/process work and do not run feature/build/acceptance/release lanes unless separately requested.

## Platform Scope

- Target platform: browser-based Web app development.
- Current build shape: React + Vite + TypeScript app built into `dist/`.
- Primary UI stack: React components, CSS, browser media APIs, localStorage persistence, and a Vite dev/preview proxy for user-configured media APIs.
- Media/system integrations: HTML video, hls.js, iframe fallback for webpage players, browser downloads, localStorage, and browser keyboard/focus behavior.
- Do not introduce macOS, iOS, server product, native app packaging, or mobile release workflow assumptions unless the codebase explicitly adds those targets.

## Workflow Files

Use the detailed step files in `Docs/Workflow/`:

1. [Start Here](Docs/Workflow/00-StartHere.md)
2. [Feature Intake](Docs/Workflow/01-FeatureIntake.md)
3. [Plan-First Implementation](Docs/Workflow/02-PlanFirstImplementation.md)
4. [Web Acceptance](Docs/Workflow/03-WebAcceptance.md)
5. [Documentation](Docs/Workflow/04-Documentation.md)
6. [Package, GitHub, and Release](Docs/Workflow/05-PackageGitHubRelease.md)
7. [Final Gate](Docs/Workflow/06-FinalGate.md)

Each file defines when the step applies, what to do, and what counts as done.

## Default Lanes

Pick the smallest lane that honestly handles the request.

### User-visible feature or bug fix

1. Start Here
2. Feature Intake
3. Plan-First Implementation
4. Web Acceptance
5. Documentation
6. Final Gate

Use Package, GitHub, and Release only when the user asks to ship, publish, push, create a PR, or update a release.

### Internal refactor

1. Start Here
2. Plan-First Implementation
3. Documentation only if architecture, setup, or developer behavior changed
4. Final Gate

Run Web Acceptance only when the refactor can plausibly affect visible behavior.

### Documentation-only change

1. Start Here
2. Documentation
3. Final Gate

Skip Web builds, browser acceptance, packaging, and release unless the documentation change modifies build/release instructions or the user asks for full verification.

### Packaging, publishing, or release task

1. Start Here
2. Package, GitHub, and Release
3. Final Gate

Do not publish or push as a side effect of ordinary implementation work.

## Hard Rules

- Preserve unrelated user changes. Never use destructive git commands or revert user work unless explicitly requested.
- Use scoped edits and prefer existing React/Vite/TypeScript patterns.
- Use `apply_patch` for manual file edits.
- Keep private source names, source URLs, credentials, and private testing details out of committed docs, acceptance notes, and release notes.
- Keep browser behavior in view: CORS/proxy behavior, keyboard focus, media playback, responsive layout, localStorage persistence, and download limitations matter.
- Verification should match risk. Run `npm test` and `npm run build` for code changes, and use real browser acceptance for user-visible workflows.
- Commit, push, PR creation, packaging, and GitHub Release updates require an explicit user request or a release/publish task.

## Architecture Reminders

Xvideo Web uses a lightweight layered frontend style:

- `src/main.tsx` and `src/App.tsx`: process entry point, dependency assembly, app shell, route-level state.
- `src/components`: React presentation components and browser interaction surfaces.
- `src/hooks`: observable application state, persistence orchestration, downloads, and view-model-like workflows.
- `src/services`: media API client, XML/JSON parsing, playback source parsing, formatting, proxy URL helpers, and localStorage adapters.
- `src/types.ts`: shared product models and TypeScript contracts.

Dependency direction:

```text
Components -> Hooks -> Services -> Types
App -> Components + Hooks
```

`services` must not depend on React components. Keep browser-only APIs localized to hooks or services that explicitly own persistence, downloads, or network proxy behavior. Prefer small changes in the owning layer over broad rewrites or new abstractions.

## Project Constants

- App/UI brand: `Xvideo`.
- Dev server command: `npm run dev`.
- Build command: `npm run build`.
- Test command: `npm test`.
- Build output path: `dist/`.
- Release asset format when packaged manually: `Xvideo-Web-YYYY-MM-DD.zip`.
