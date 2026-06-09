# Plan-First Implementation

Use this step for every code change.

## Purpose

Plan narrowly, implement in the owning layer, and verify compilation before deeper testing.

## Steps

1. Build an implementation plan.
   - Identify the files and layers likely to change.
   - Respect the dependency direction in `AGENTS.md`.
   - Prefer small changes in existing structures over new abstractions.
   - Keep AppKit interop narrow and localized.
2. Record the plan with Codex's plan mechanism when available.
   - Keep steps concrete and checkable.
   - Update the plan as facts change.
3. Implement the smallest complete change.
   - `Domain`: models, repository protocols, business rules, source URL interpretation, and use cases.
   - `Data`: network clients, API parsing, XML/JSON handling, and repository implementations.
   - `Infrastructure`: persistence, downloads, filesystem, Finder, and other macOS system services.
   - `Presentation`: SwiftUI views, observable state, user interaction, layout, focus, and visible error/loading states.
   - `App`: entry point and dependency assembly.
4. Apply macOS engineering checks while coding.
   - Keep UI responsive on the main actor.
   - Avoid blocking playback, downloads, or network operations on the main thread.
   - Keep window minimum sizes, keyboard shortcuts, focus, and menu/window behavior stable.
   - Handle cancellation and stale async results in view models.
5. Compile after code edits.
   - Run `swift build`.
   - Fix compiler errors before app packaging or acceptance work.
6. Add focused checks when practical.
   - Prefer unit or lightweight command checks for Domain, Data, parsing, and persistence logic.
   - If adding substantial reusable logic and no test target exists, consider adding a small Swift test target when the risk justifies it.

## Done When

- The implementation is scoped to the request.
- `swift build` passes for code changes.
- Relevant focused checks have passed or skipped checks are explained.
