# Xvideo Agent Workflow

This root `AGENTS.md` is loaded by Codex for this repository. Follow it for every project change unless the user explicitly says to skip a step.

The workflow is intentionally project-local: the skills below are Xvideo-only working agreements, not reusable global Codex skills. Every substantial request should move through the same path from feature intake to release.

## Always Start Here

1. Inspect first.
   - Run `git status -sb`.
   - Check the current branch, remote, recent commits, and files relevant to the request.
   - Preserve unrelated user changes. Never use destructive git commands or revert user work unless explicitly requested.
2. Read context before editing.
   - Read `Docs/FeatureList.md` for the current product surface.
   - Read `Docs/Architecture.md` before changing structure, data flow, packaging, or release behavior.
   - Read nearby SwiftUI/AppKit/domain files before planning code changes.
3. Use scoped edits.
   - Keep changes limited to the requested behavior and its direct documentation, tests, packaging, and release artifacts.
   - Use existing SwiftUI/AppKit and Clean Architecture patterns.
   - Use `apply_patch` for manual edits.

## Project-Local Skills

Each large workflow phase must call the matching project-local skill. "Call" means explicitly follow that skill's checklist and name it in the working notes or final summary when it materially shaped the work.

### Skill: Xvideo Feature Intake

Use this skill whenever the user asks for a new feature, UI behavior, bug fix with user-visible impact, or workflow change.

Purpose:
- Turn the user's request into a maintained product requirement before implementation.
- Keep `Docs/FeatureList.md` as the source of truth for implemented and planned behavior.

Steps:
1. Compare the request with the current code and `Docs/FeatureList.md`.
2. Write a short requirement analysis:
   - What user problem is being solved.
   - Which current behavior already exists.
   - Which behavior must change.
   - Constraints from `Docs/Architecture.md`.
3. Update `Docs/FeatureList.md` before or alongside the code change:
   - Add the requested feature to the right feature area.
   - Mark planned or in-progress behavior clearly if the implementation is not complete yet.
   - Remove or adjust stale entries only when the code actually changed.
4. Create or update a feature acceptance document under `Docs/Acceptance/`.
   - Use a stable name such as `Docs/Acceptance/<feature-slug>.md`.
   - Include requirement summary, scope, prerequisites, test data assumptions without private source details, and a checklist that maps directly back to `Docs/FeatureList.md`.

### Skill: Xvideo Plan-First Implementation

Use this skill for every code change.

Purpose:
- Make Codex plan the work before editing, then implement against the plan.
- Avoid broad rewrites, hidden inference, and unreviewable changes.

Steps:
1. Build an implementation plan from the requirement analysis and existing code.
   - Identify the files and layers likely to change.
   - Respect the dependency direction in `Docs/Architecture.md`.
   - Prefer small changes in the owning layer over new abstractions.
2. Record the plan with Codex's plan mechanism when available.
   - Keep the plan concrete enough to check off.
   - Update the plan as facts change.
3. Implement the smallest complete version of the feature.
   - Domain rules belong in `Domain`.
   - API and parsing details belong in `Data`.
   - System persistence, downloads, and files belong in `Infrastructure`.
   - SwiftUI state and user interaction belong in `Presentation`.
   - App assembly belongs in `App`.
4. Compile after code edits.
   - Run `swift build`.
   - Fix all compiler errors before testing or packaging.
5. Add focused checks for changed logic when practical.
   - Prefer direct tests or lightweight command checks for domain/data logic.
   - For UI/player workflows, the acceptance skill below is required.

### Skill: Xvideo Acceptance With Computer Use

Use this skill after any user-visible feature, UI behavior, player behavior, source-management behavior, search/browse behavior, persistence behavior, download behavior, or bug fix.

Purpose:
- Validate the app through the real macOS workflow, not only through code inspection.
- Produce a pass/fail acceptance result tied to `Docs/FeatureList.md`.

Steps:
1. Prepare the app.
   - Run `Scripts/build_app.sh`.
   - Launch `.build/app/Xvideo.app`.
2. Use `@computer use` for functional click-through confirmation.
   - Click through the exact flow described in the acceptance document.
   - Verify visible UI states, navigation, persistence, playback/download state, error handling, and recovery behavior as applicable.
   - Do not record concrete private data source names, source URLs, credentials, or private testing details in committed docs or release notes.
3. Update the acceptance document under `Docs/Acceptance/`.
   - Mark each checklist item as pass, fail, blocked, or not applicable.
   - Include concise evidence: build command, app launch path, tested workflow, and observed result.
   - End with a clear conclusion: `Accepted`, `Rejected`, or `Blocked`.
4. If acceptance fails:
   - Fix the issue.
   - Rebuild.
   - Repeat the computer-use acceptance pass.
5. If `@computer use` is unavailable:
   - Run all non-interactive checks that still apply.
   - Mark the computer-use portion as blocked in the acceptance document and final response.
   - Do not claim full UI acceptance passed.

### Skill: Xvideo Documentation

Use this skill whenever behavior, UI, setup, screenshots, source handling, build instructions, or usage changes.

Purpose:
- Keep user-facing docs honest and minimal.

Steps:
1. Check `README.md` for every change.
   - Update it for user-visible feature, UI, setup, source, screenshot, build, or usage changes.
   - If no README update is needed, say so in the final response.
2. Keep `README.en.md` aligned when the same user-visible information exists there.
3. Keep `Docs/FeatureList.md` aligned with the final behavior after implementation.
4. Keep acceptance docs factual and free of private source details.

### Skill: Xvideo Package, GitHub, and Release

Use this skill after code or app behavior changes. For docs-only changes, commit and push are still required, but app packaging and GitHub Release updates are not required unless the user asks.

Purpose:
- Ship a verified macOS app package and keep GitHub releases consistent.

Steps:
1. Confirm verification is complete.
   - `swift build` passed when code changed.
   - `Scripts/build_app.sh` passed for app/UI/player/user-visible changes.
   - Acceptance document has a final conclusion.
2. Commit and push.
   - Stage only task-related files.
   - Commit locally with a clear message using the `Docs/Architecture.md` commit type guidance.
   - Push to GitHub after the commit succeeds.
3. Package the app when code or app behavior changed.
   - Use date-only tags such as `2026-05-26`.
   - Preserve older date releases; replacing the same-day app asset is allowed.
   - Build asset name: `Xvideo-YYYY-MM-DD-macOS.zip`.
   - Package command:
     ```bash
     ditto -c -k --sequesterRsrc --keepParent .build/app/Xvideo.app .build/releases/Xvideo-YYYY-MM-DD-macOS.zip
     ```
4. Compute the asset SHA-256.
5. Create or update the GitHub Release.
   - Keep release notes bilingual and consistently ordered:
     1. `中文`
     2. `English`
     3. `Verification`
     4. `Build`
   - Include asset name and SHA-256.
   - Do not include concrete data source names, source URLs, credentials, or private testing details.
   - Preserve older releases and assets unless intentionally replacing the same-day app asset.

### Skill: Xvideo Final Gate

Use this skill before every final response.

Purpose:
- Make sure the repository is left in a clear, verifiable state.

Steps:
1. Run `git status -sb`.
2. Confirm whether the branch is ahead/behind the remote.
3. Confirm README status:
   - Updated, or
   - Not needed, with a short reason.
4. Confirm build/test status:
   - Include commands run and outcomes.
   - State any skipped checks and why.
5. Confirm release status:
   - Release updated, or
   - Not needed because the change was docs-only or explicitly unreleased.

## End-to-End Workflow

For a normal feature request, use the skills in this order:

1. `Xvideo Feature Intake`
   - Analyze the requirement against current code.
   - Maintain `Docs/FeatureList.md`.
   - Create or update `Docs/Acceptance/<feature-slug>.md`.
2. `Xvideo Plan-First Implementation`
   - Use Codex's plan mechanism.
   - Implement against the plan.
   - Run `swift build`.
3. `Xvideo Acceptance With Computer Use`
   - Run `Scripts/build_app.sh`.
   - Launch `.build/app/Xvideo.app`.
   - Use `@computer use` to click through the acceptance checklist.
   - Update the acceptance document with pass/fail conclusion.
4. `Xvideo Documentation`
   - Update `README.md` and `README.en.md` when user-visible behavior changed.
   - Reconcile `Docs/FeatureList.md` with the final shipped behavior.
5. `Xvideo Package, GitHub, and Release`
   - Commit and push task-related files.
   - For code or app behavior changes, package the app, upload the asset, update GitHub Release, and write release notes.
6. `Xvideo Final Gate`
   - Report working tree, push status, README status, verification, and release status.

## Lightweight Exceptions

- Documentation-only changes:
  - Inspect first.
  - Edit docs.
  - Check whether README changes are needed.
  - Commit and push.
  - Skip `swift build`, app launch, packaging, and release unless the docs affect build/release instructions or the user asks for full verification.
- Pure internal refactors:
  - Still use plan-first implementation.
  - Run `swift build`.
  - Run focused checks.
  - Use computer-use acceptance only if behavior can change from the user's perspective.
- Emergency fixes:
  - Keep the plan short, but still maintain `Docs/FeatureList.md` and acceptance docs if the fix changes user-visible behavior.

## Project Rules

- App name and UI brand: `Xvideo`.
- Built app path: `.build/app/Xvideo.app`.
- Build script: `Scripts/build_app.sh`.
- Release asset format: `Xvideo-YYYY-MM-DD-macOS.zip`.
- Never include concrete private data source names, source URLs, credentials, or private testing details in committed docs or release notes.
- Never use destructive git commands or revert user changes unless explicitly requested.
