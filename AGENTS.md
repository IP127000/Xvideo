# Xvideo iOS Branch Agent Workflow

This repository branch is for iOS app development. Treat iPhone as the default product surface unless the user explicitly asks for another iOS device class. Non-iOS app behavior can exist only as shared-code or historical context; non-iOS packaging, UI acceptance, release work, and desktop-first product decisions are out of scope by default.

Follow the workflow below for project changes on the `ios` branch. Scale the checks to the risk of the change. If the user explicitly asks to revise the workflow itself, audit process documentation only. If the user explicitly asks to skip a workflow gate, do not run that gate; record the skip and the residual risk instead.

## Core Principles

1. Protect the working tree.
   - Start with `git status -sb`.
   - For workflow-audit requests where the user explicitly says not to run workflow steps, limit this to repository-safety inspection and doc diffs needed to avoid overwriting user work.
   - Preserve unrelated user changes and untracked files.
   - Never use destructive git commands or revert user work unless explicitly requested.
2. Read the smallest useful context before editing.
   - Read `Docs/FeatureList.md` when behavior, UI, source handling, playback, persistence, downloads, setup, signing, install, or acceptance changes.
   - Read `Docs/Architecture.md` before changing structure, data flow, iOS packaging, signing, install, distribution behavior, or cross-layer ownership.
   - Read process notes under `Docs/` when changing this workflow or project-local workflow skills.
   - Read nearby SwiftUI/UIKit/domain/data/infrastructure files before code changes.
3. Keep changes scoped.
   - Prefer the existing Clean Architecture boundaries and local coding style.
   - Put domain rules in `Domain`, API/parsing in `Data`, filesystem/download/system concerns in `Infrastructure`, SwiftUI state and iOS interaction in `Presentation`, and dependency assembly in `App`.
   - Use `apply_patch` for manual edits.
4. Verify proportionally.
   - Compile and test what the change can realistically affect.
   - Use iOS Simulator or browser-backed simulator tooling as the default surface for full functional UI validation after user-visible changes.
   - Use a physical iPhone for signed install confirmation when a paired trusted device is available; treat launch as an optional command-side smoke check only when the install tool performs it or the change specifically needs it.
   - Mark unavailable device, signing, or trust conditions as blocked acceptance, not as code failures.
   - After validation, close Simulator sessions and clean temporary validation artifacts. Keep only explicitly requested release/distribution files.
5. Keep private details out of committed text.
   - Do not record concrete private source names, source URLs, credentials, personal device-owner details, or private test data in docs, acceptance notes, commits, or release notes.

## Skill and Tool Selection

Use project-local workflow skills first, then tool/plugin skills only when they directly fit the selected level.

- Use iOS-specific skills and tools for SwiftUI, Simulator, App Intents, iOS performance, iOS memory, signing, install, and device debugging.
- Use simulator or browser-backed iOS tooling for functional UI evidence when it faithfully represents the iPhone behavior under test. Prefer this for source management, browsing, search, detail, playback controls, fullscreen, favorites, continue watching, downloads, and persistence flows.
- Use physical iPhone acceptance for signed install only by default. Treat launch/process checks as optional command-side smoke evidence, not as functional phone testing. Do not use the phone for exhaustive manual UI click-through unless the user explicitly requests physical UI confirmation or the behavior is device-only.
- Do not use non-iOS app skills, desktop build scripts, desktop Computer Use, or non-iOS release habits as substitutes for iOS validation.
- Use GitHub or publishing skills after verified code or script changes so the change is submitted to GitHub, unless the user explicitly asks not to publish or GitHub access is blocked. Documentation-only workflow edits still do not require publication unless requested.
- Treat `Docs/AnimekoAlignmentPlan.md` as product-direction context only; it does not define independent gates outside this file.

## Workflow Levels

Choose the lightest level that fully covers the request. Move up a level when the change affects more surface area than expected.

### Level 0: Workflow, Process, or Documentation Only

Use for edits to `AGENTS.md`, process docs, README wording, acceptance-document cleanup, or non-behavioral documentation.

- Inspect the working tree.
- Read `AGENTS.md` and the relevant process, architecture, feature, or acceptance docs.
- Edit only the requested documentation.
- Do not update `Docs/FeatureList.md` unless documented product behavior changed.
- Do not create acceptance docs unless the documentation describes a new testable behavior.
- Skip iOS build, install, launch, simulator checks, and acceptance unless the docs change build/signing/install instructions and the user wants that verification.
- Do not commit or push unless the user asks.

### Level 1: Internal Code, Refactor, or Test-Only Change

Use when user-visible iOS behavior should not change.

- Follow `Xvideo iOS Plan-First Implementation`.
- Read `Docs/Architecture.md` and nearby code.
- Run the iOS compile gate after code edits:
  ```bash
  swift build --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
  ```
- Add or run focused tests/checks when practical.
- Do not perform physical iPhone acceptance unless the change can alter runtime behavior despite being intended as internal.
- Update docs only when public behavior, setup, or architecture guidance changed.

### Level 2: User-Visible iOS Behavior

Use for iPhone UI, playback, source management, search/browse, favorites, continue-watching, persistence, downloads, or bug fixes with visible impact.

- Follow `Xvideo iOS Feature Intake`.
- Follow `Xvideo iOS Plan-First Implementation`.
- Update `Docs/FeatureList.md` for durable product behavior changes.
- Create or update `Docs/Acceptance/<feature-slug>.md` when the behavior needs user-flow validation.
- Run the iOS compile gate.
- Use iOS Simulator or browser-backed simulator tooling for full functional validation when it faithfully represents the behavior.
- Use `Xvideo iPhone Acceptance` for the signed app install gate. If the install script launches the app, record launch/process state only as command-side smoke evidence.
- Do not ask for physical phone UI click-through by default. Ask for the smallest necessary on-phone confirmation only when the flow is device-only or the user explicitly requested physical UI validation.
- After simulator validation, stop the app, close or shut down the simulator used for testing, stop mirror/helper processes, and remove temporary servers, mock data, screenshots, logs, and generated validation files unless they are explicit release artifacts.
- When code or scripts changed, follow `Xvideo iOS Publish and Package` after verification unless the user explicitly asked not to submit the code.

### Level 3: iOS Signing, Install, Device, or Distribution Workflow

Use when scripts, signing, install, bundle identifiers, entitlements, provisioning, or device launch behavior change.

- Follow `Xvideo iOS Feature Intake` if the change affects users or developers.
- Follow `Xvideo iOS Plan-First Implementation`.
- Run the iOS compile gate.
- Build the signed iPhone app with:
  ```bash
  IOS_DEVICE_UDID="<iphone-udid>" Scripts/build_ios_xcode_app.sh
  ```
- Install on a paired trusted device when available. The install script may also launch the app; use that only as command-side smoke evidence, not full phone UI testing:
  ```bash
  IOS_DEVICE_ID="<paired-device-id>" Scripts/install_ios_app.sh
  ```
- Confirm installed app state with `devicectl`; check running state only when the install command or task intentionally launches the app.
- Document blockers precisely: no device, locked device, Developer Mode disabled, untrusted developer profile, missing signing identity, unavailable provisioning, or launch failure when launch was part of the command path.
- Clean generated signing/install intermediates after verification unless they are explicit release artifacts requested by the user.
- Do not create distribution artifacts, publish packages, or update releases unless explicitly requested.

## Project-Local Workflow Skills

These repository-local skills have dedicated checklists under `Docs/WorkflowSkills/`. Use the skills that match the selected workflow level and name them in the final summary when they materially shaped the work. The linked skill file is the authoritative checklist when this summary is ambiguous.

- `Xvideo iOS Feature Intake`: `Docs/WorkflowSkills/FeatureIntake.md`
- `Xvideo iOS Plan-First Implementation`: `Docs/WorkflowSkills/PlanFirstImplementation.md`
- `Xvideo iPhone Acceptance`: `Docs/WorkflowSkills/IPhoneAcceptance.md`
- `Xvideo iOS Documentation`: `Docs/WorkflowSkills/Documentation.md`
- `Xvideo iOS Publish and Package`: `Docs/WorkflowSkills/PublishAndPackage.md`
- `Xvideo iOS Closeout`: `Docs/WorkflowSkills/Closeout.md`

### Skill: Xvideo iOS Feature Intake

Use for new iOS features, iPhone UI behavior, playback behavior, source/search/browse behavior, persistence/download behavior, signing/install workflow changes, or user-visible bug fixes.
Full checklist: `Docs/WorkflowSkills/FeatureIntake.md`.

Purpose:
- Convert the request into a maintained iOS product requirement.
- Keep `Docs/FeatureList.md` aligned with implemented and planned behavior on the `ios` branch.

Steps:
1. Compare the request with current code and `Docs/FeatureList.md`.
2. Write a short requirement analysis in the working notes:
   - User problem on iPhone.
   - Existing behavior.
   - Required behavior change.
   - Constraints from `Docs/Architecture.md`, iOS signing, and device testing.
3. Update `Docs/FeatureList.md` when durable product behavior changes.
   - Mark planned, in-progress, blocked, or implemented behavior honestly.
   - Remove stale entries only when the code or product decision actually changed.
4. Create or update `Docs/Acceptance/<feature-slug>.md` when the behavior needs acceptance evidence.
   - Include requirement summary, scope, prerequisites, device/signing assumptions without private details, and a checklist mapped to `Docs/FeatureList.md`.
   - For tiny visible copy/layout changes, acceptance may be a concise note in the final response instead of a new document.

### Skill: Xvideo iOS Plan-First Implementation

Use for every code or script change on the `ios` branch.
Full checklist: `Docs/WorkflowSkills/PlanFirstImplementation.md`.

Purpose:
- Plan before editing.
- Keep changes reviewable and aligned with architecture.

Steps:
1. Build an implementation plan from the requirement analysis and existing code.
   - Identify files and layers likely to change.
   - Respect the dependency direction in `Docs/Architecture.md`.
   - Prefer small edits in the owning layer over new abstractions.
2. Record the plan with Codex's plan mechanism when available.
3. Implement the smallest complete version of the change.
4. Compile after code edits:
   ```bash
   swift build --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
   ```
5. Add focused checks for changed logic when practical.
   - Use direct tests or lightweight command checks for domain/data logic.
   - Move to `Xvideo iPhone Acceptance` when the change affects real iPhone workflows.
6. After verified code or script changes, move to `Xvideo iOS Publish and Package` unless the user explicitly asked not to submit the code or GitHub access is blocked.

### Skill: Xvideo iPhone Acceptance

Use after meaningful iPhone user-visible changes and after signing/install workflow changes. Do not use desktop Computer Use as a substitute for iPhone acceptance.
Full checklist: `Docs/WorkflowSkills/IPhoneAcceptance.md`.

Purpose:
- Validate the iOS build, Simulator user-flow path, physical iPhone install path, and cleanup state when it matters.
- Produce a pass/fail/blocked acceptance result tied to `Docs/FeatureList.md`.

Steps:
1. Decide the acceptance surface.
   - Use iOS Simulator or browser-backed iOS UI tooling for full functional flows when it faithfully represents the requested iPhone behavior.
   - Use a physical iPhone only for signed install and command-side device state by default.
   - Use physical phone UI click-through only when the user explicitly requests it or when the behavior is device-only.
2. Run Simulator functional validation for meaningful user-visible behavior.
   - Cover the actual tap, input, scroll, playback, persistence, download, source-management, or navigation path.
   - Use the user-provided source when safe, and use local mock sources only for gaps such as download fields that the provided source cannot exercise.
   - Record evidence without private source names, concrete source URLs, credentials, or personal device details.
3. Prepare the signed iPhone app when a real device install check is needed:
   ```bash
   IOS_DEVICE_UDID="<iphone-udid>" Scripts/build_ios_xcode_app.sh
   ```
   The script generates a temporary Xcode project under `.build/ios-xcode`, signs with the local Apple Development team, and copies the signed app to `.build/ios-device/Xvideo.app`.
4. Install on the paired iPhone when available. The current install script may launch the app; use launch only as command-side smoke evidence:
   ```bash
   IOS_DEVICE_ID="<paired-device-id>" Scripts/install_ios_app.sh
   ```
5. Verify command-side device state after install, and process state only when launch was part of the command path:
   ```bash
   xcrun devicectl device info apps --device "<paired-device-id>"
   xcrun devicectl device info processes --device "<paired-device-id>"
   ```
6. Mark each checklist item.
   - For physical-device-only checks or explicit physical UI requests, ask the user for the smallest necessary confirmation.
   - Mark each checklist item pass, fail, blocked, pending, or not applicable.
7. Update the acceptance document when one exists.
   - Include concise evidence: command, outcome, signed app path, device-state result, tested workflow, and observed result.
   - End with `Accepted`, `Rejected`, or `Blocked`.
8. If acceptance fails because of code behavior, fix and repeat the relevant build, Simulator validation, install, and acceptance checks.
9. After simulator or browser-backed validation, stop the app, close or shut down the simulator, stop simulator mirror/helper processes, and remove temporary mock servers, generated test data, screenshots, logs, and build products unless they are explicit release artifacts.

### Skill: Xvideo iOS Documentation

Use when iOS behavior, UI, setup, signing, install, source handling, screenshots, build instructions, or usage changes.
Full checklist: `Docs/WorkflowSkills/Documentation.md`.

Purpose:
- Keep user-facing docs accurate without forcing unrelated doc churn.

Steps:
1. Check `README.md` when public usage, setup, signing, source handling, screenshots, build, install, or behavior changes.
   - Update it only when the README contains information affected by the change.
   - If no README update is needed, say why in the final response.
2. Keep `README.en.md` aligned when the same user-visible information exists there.
3. Keep `Docs/FeatureList.md` aligned with final iOS behavior.
4. Keep acceptance docs factual and free of private source details.

### Skill: Xvideo iOS Publish and Package

Use after verified code or script changes, when the user asks to commit, push, publish, package, or prepare release artifacts, or when a task explicitly includes repository publication.
Full checklist: `Docs/WorkflowSkills/PublishAndPackage.md`.

Purpose:
- Publish only intentional, verified iOS branch changes.
- Avoid accidentally shipping non-iOS artifacts from the iOS branch.

Steps:
1. Confirm verification appropriate to the workflow level is complete.
2. Stage only task-related files.
3. Commit locally with the type guidance from `Docs/Architecture.md`:
   - `feat:` user-visible functionality
   - `fix:` bug fixes
   - `refactor:` internal structure changes without behavior changes
   - `docs:` documentation-only changes
   - `chore:` tooling, scripts, repository setup
4. Push after the commit succeeds for verified code or script changes unless the user explicitly asked not to publish or GitHub access is blocked.
5. Do not update GitHub Releases or prepare distribution artifacts unless the user explicitly asks for iOS distribution work.
6. Treat signed `.app` bundles as local development artifacts unless the user asks for an iOS distribution package.

### Skill: Xvideo iOS Closeout

Use before final responses after project changes, scaled to the work performed. If the user explicitly asked to skip workflow gates or requested a workflow audit only, keep closeout to the facts already gathered plus skipped-gate notes.
Full checklist: `Docs/WorkflowSkills/Closeout.md`.

Purpose:
- Leave the repository state and verification status clear.

Steps:
1. Run `git status -sb` when files were changed or when current status is not already known.
2. Report ahead/behind state when visible.
3. Report documentation status when relevant:
   - Updated, or
   - Not needed, with a short reason.
4. Report verification status:
   - Commands run and outcomes.
   - Checks skipped and why.
   - Physical iPhone UI items that remain blocked or pending.
   - Simulator/browser validation performed and cleanup performed.
   - Temporary artifacts kept or removed, and why.
5. Report publish/package status only when relevant:
   - Completed GitHub publication for code or script changes.
   - Not performed for documentation-only changes unless the user asked.
   - Blocked publication, with the reason.

## Common Paths

### Normal iOS Feature or User-Visible Bug Fix

1. Core preflight.
2. `Xvideo iOS Feature Intake`.
3. `Xvideo iOS Plan-First Implementation`.
4. `Xvideo iOS Documentation`.
5. `Xvideo iPhone Acceptance`, using Simulator/browser tooling for full functional validation and physical iPhone for signed install confirmation.
6. Cleanup: close Simulator, stop helper processes, and remove temporary validation artifacts except explicit release artifacts.
7. `Xvideo iOS Publish and Package` when code or scripts changed, unless the user explicitly asked not to publish.
8. `Xvideo iOS Closeout`.

### Documentation-Only or Workflow-Only Change

1. Core preflight.
2. Read the relevant docs.
3. Edit docs only.
4. Skip build/install/acceptance unless the docs change build, signing, install, or distribution instructions and the user wants verification.
5. Skip commit/push unless the user asks.
6. `Xvideo iOS Closeout`.

### Internal Refactor

1. Core preflight.
2. `Xvideo iOS Plan-First Implementation`.
3. Run the iOS compile gate.
4. Run focused tests/checks when practical.
5. Use Simulator/browser functional validation only if behavior can change from the user's perspective.
6. Cleanup simulator/helper/temp artifacts when validation used them.
7. `Xvideo iOS Publish and Package` when code or scripts changed, unless the user explicitly asked not to publish.
8. `Xvideo iOS Closeout`.

### Emergency Fix

1. Keep the plan short.
2. Preserve the architecture boundary.
3. Compile and run the smallest meaningful check.
4. Use Simulator/browser validation for the smallest meaningful user flow when the fix is visible.
5. Install the fixed app on the physical iPhone for signed install confirmation when signing is available.
6. Cleanup simulator/helper/temp artifacts after validation.
7. Publish verified code/script fixes to GitHub unless the user explicitly asked not to publish or access is blocked.
8. Update `Docs/FeatureList.md` and acceptance docs only when user-visible iOS behavior changed.
9. `Xvideo iOS Closeout`.

## Project Rules

- App name and UI brand: `Xvideo`.
- Default product target on this branch: iPhone iOS app.
- Signed iPhone app path: `.build/ios-device/Xvideo.app`.
- iOS automatic-signing build script: `Scripts/build_ios_xcode_app.sh`.
- iOS manual/ad-hoc build script: `Scripts/build_ios_app.sh`.
- iOS install script: `Scripts/install_ios_app.sh` currently installs and then launches as a command-side smoke check.
- Non-iOS app build scripts, packages, UI acceptance, and releases are out of scope unless the user explicitly asks for a non-iOS task.
- Do not include concrete private data source names, source URLs, credentials, device owner personal details, or private testing details in committed docs or release notes.
- Do not use destructive git commands or revert user changes unless explicitly requested.
- After validation, clean temporary simulator mirrors, local mock servers, generated UI-test data, screenshots, logs, DerivedData, and non-release build outputs when practical. Keep only explicit release/distribution artifacts requested by the user.
