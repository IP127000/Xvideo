# Xvideo iOS Plan-First Implementation Skill

Use this skill for every code or script change on the `ios` branch.

## Purpose

- Plan before editing so changes stay reviewable.
- Keep implementation inside the existing Clean Architecture boundaries.
- Verify the smallest realistic iOS surface affected by the change.

## Procedure

1. Build an implementation plan from the requirement analysis and existing code.
   - Identify files and layers likely to change.
   - Respect the dependency direction in `Docs/Architecture.md`.
   - Prefer small edits in the owning layer over broad rewrites or new abstractions.
2. Record the plan with Codex's plan mechanism when available.
   - Keep the plan concrete enough to update as facts change.
   - Do not let planning replace reading nearby code.
3. Implement the smallest complete version of the change.
   - Domain rules belong in `Domain`.
   - API and parsing details belong in `Data`.
   - Filesystem, download, and system concerns belong in `Infrastructure`.
   - SwiftUI state and iPhone interaction belong in `Presentation`.
   - Dependency assembly belongs in `App`.
4. Compile after code edits:
   ```bash
   swift build --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
   ```
5. Add focused checks when practical.
   - Use direct tests or lightweight command checks for domain/data logic.
   - Move to `Xvideo iPhone Acceptance` when the change affects real iPhone workflows.

## Skip Rules

- Do not run the compile gate for workflow-only or documentation-only changes unless the docs alter build, signing, install, or distribution instructions and the user wants verification.
- Do not run non-iOS app build scripts as default verification for this branch.
- Do not refactor unrelated layers while making a narrow behavior change.

## Output

Report the implementation scope, iOS compile result when code changed, focused checks run, and any skipped checks with reasons.
