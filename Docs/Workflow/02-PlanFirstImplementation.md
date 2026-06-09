# Plan-First Implementation

Use this step for every code change.

## Purpose

Plan narrowly, implement in the owning layer, and verify tests/build before deeper browser testing.

## Steps

1. Build an implementation plan.
   - Identify the files and layers likely to change.
   - Respect the dependency direction in `AGENTS.md`.
   - Prefer small changes in existing structures over new abstractions.
   - Keep proxy/server behavior narrow and localized to Vite middleware when possible.
2. Record the plan with Codex's plan mechanism when available.
   - Keep steps concrete and checkable.
   - Update the plan as facts change.
3. Implement the smallest complete change.
   - `src/types.ts`: shared product contracts.
   - `src/services`: API parsing, playback parsing, proxy helpers, localStorage adapters, formatting, and focused tests.
   - `src/hooks`: app state, persistence orchestration, downloads, and view-model-like workflows.
   - `src/components`: React UI, accessibility, visible states, and user interactions.
   - `src/styles.css`: design tokens, layout, responsive behavior, and visual states.
   - `vite.config.ts`: dev/preview proxy and build configuration.
4. Apply Web engineering checks while coding.
   - Keep data loading cancellable or guarded against stale results where practical.
   - Avoid blocking the main thread with large synchronous work in render.
   - Keep media, downloads, localStorage, and proxy behavior clear about browser limitations.
   - Keep responsive layouts stable and avoid text overlap or clipped controls.
5. Verify after code edits.
   - Run `npm test` when logic, parsing, source handling, state, or persistence changed.
   - Run `npm run build`.
   - Fix compiler, test, and bundling errors before browser acceptance.
6. Add focused checks when practical.
   - Prefer Vitest checks for service parsing, source parsing, formatting, and storage-adjacent logic.
   - Add browser interaction checks for user-visible workflows.

## Done When

- The implementation is scoped to the request.
- `npm run build` passes for code changes.
- Relevant focused checks have passed or skipped checks are explained.
