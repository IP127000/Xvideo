# Xvideo Architecture

Xvideo uses a lightweight Clean Architecture style. On the `ios` branch, the default product target is the iOS app, with iPhone as the primary surface. The goal is to keep API details, business rules, and SwiftUI state separate enough that future work can be changed in one layer without surprising the others.

## Layers

```text
App
  Dependency assembly and process entry point.

Presentation
  SwiftUI views and observable view models.

Domain
  App models, repository protocols, source parsing, and use cases.

Data
  Remote API clients and repository implementations.

Infrastructure
  System integrations such as downloads and filesystem access.

Shared
  Small cross-cutting helpers and extensions.
```

## Dependency Direction

Dependencies point inward:

```text
Presentation -> Domain
Data -> Domain
App -> Presentation + Data + Domain + Infrastructure
Infrastructure -> Domain where needed
```

`Domain` does not know about SwiftUI, URLSession, UIKit/AppKit windows, or file locations.

## Important Use Cases

- `LoadLibraryPageUseCase`
  - Chooses the correct API path for search versus category browsing.
  - Aggregates parent categories with child categories.
  - Deduplicates and sorts merged category pages.

- `LoadMovieDetailUseCase`
  - Uses cached detailed list items when they already include playback URLs.
  - Falls back to a detail request when needed.

## Git Workflow

Use the workflow level in `AGENTS.md` and the matching `Docs/WorkflowSkills/` checklist first. Commit and push only when the user asks to publish work or the task explicitly includes repository publication.

When committing, use small commits with a clear type:

- `feat:` user-visible functionality
- `fix:` bug fixes
- `refactor:` internal structure changes without behavior changes
- `docs:` documentation-only changes
- `chore:` tooling, scripts, repository setup

Suggested iOS branch flow:

```bash
git status
swift build --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
git add <task-related-files>
git commit -m "refactor: move library loading rules into domain use cases"
```

Do not use `git add .` unless the working tree contains only task-related changes. For larger work, commit the stable baseline first, then commit the refactor or feature separately. Non-iOS builds, packages, UI acceptance, and releases are not default gates on the `ios` branch.
