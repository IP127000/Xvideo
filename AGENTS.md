# Xvideo macOS Agent Workflow

This repository is a macOS-only Swift app. These instructions are project-local working agreements for Xvideo development, documentation, verification, packaging, and release work.

Follow this workflow for repository changes unless the user explicitly asks to skip or revise it. When the user asks to revise the workflow itself, treat that as documentation/process work and do not run the feature/build/acceptance/release lanes unless separately requested.

## Platform Scope

- Target platform: macOS app development only.
- Current build shape: SwiftPM executable target packaged as `.build/app/Xvideo.app`.
- Primary UI stack: SwiftUI, with narrow AppKit interop where desktop behavior requires it.
- Media/system integrations: AVKit, WebKit, local persistence, downloads, Finder integration, and macOS window/keyboard behavior.
- Do not introduce iOS, web, server, mobile release, or cross-platform workflow assumptions unless the codebase explicitly adds those targets.

## Workflow Files

Use the detailed step files in `Docs/Workflow/`:

1. [Start Here](Docs/Workflow/00-StartHere.md)
2. [Feature Intake](Docs/Workflow/01-FeatureIntake.md)
3. [Plan-First Implementation](Docs/Workflow/02-PlanFirstImplementation.md)
4. [macOS Acceptance](Docs/Workflow/03-MacOSAcceptance.md)
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
4. macOS Acceptance
5. Documentation
6. Final Gate

Use Package, GitHub, and Release only when the user asks to ship, publish, push, create a PR, or update a release.

### Internal refactor

1. Start Here
2. Plan-First Implementation
3. Documentation only if architecture, setup, or developer behavior changed
4. Final Gate

Run macOS Acceptance only when the refactor can plausibly affect visible behavior.

### Documentation-only change

1. Start Here
2. Documentation
3. Final Gate

Skip Swift builds, app launch, packaging, and release unless the documentation change modifies build/release instructions or the user asks for full verification.

### Packaging, publishing, or release task

1. Start Here
2. Package, GitHub, and Release
3. Final Gate

Do not publish or push as a side effect of ordinary implementation work.

## Hard Rules

- Preserve unrelated user changes. Never use destructive git commands or revert user work unless explicitly requested.
- Use scoped edits and prefer existing SwiftUI/AppKit/Clean Architecture patterns.
- Use `apply_patch` for manual file edits.
- Keep private source names, source URLs, credentials, and private testing details out of committed docs, acceptance notes, and release notes.
- Keep macOS desktop behavior in view: window sizing, focus, keyboard shortcuts, menu/window integration, playback surfaces, download persistence, and Finder handoff matter.
- Verification should match risk. Compile every code change, add focused logic checks where practical, and use real macOS app acceptance for user-visible workflows.
- Commit, push, PR creation, packaging, and GitHub Release updates require an explicit user request or a release/publish task.

## Architecture Reminders

Xvideo uses a lightweight Clean Architecture style:

- `App`: process entry point and dependency assembly.
- `Presentation`: SwiftUI views and observable view models.
- `Domain`: app models, repository protocols, business rules, source URL interpretation, and use cases.
- `Data`: remote API clients, network parsing, and repository implementations.
- `Infrastructure`: filesystem, downloads, persistence, and other system integrations.
- `Shared`: small cross-cutting helpers.

Dependency direction:

```text
Presentation -> Domain
Data -> Domain
Infrastructure -> Domain where needed
App -> Presentation + Data + Domain + Infrastructure
```

`Domain` must not depend on SwiftUI, URLSession, AppKit windows, or concrete file locations. Prefer small changes in the owning layer over broad rewrites or new abstractions.

## Project Constants

- App/UI brand: `Xvideo`.
- Built app path: `.build/app/Xvideo.app`.
- Build script: `Scripts/build_app.sh`.
- Release asset format: `Xvideo-YYYY-MM-DD-macOS.zip`.
