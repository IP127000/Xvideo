# Xvideo iOS Branch Agent Workflow

This root `AGENTS.md` is loaded by Codex for this repository. On the `ios` branch, follow this iPhone-first workflow for every project change unless the user explicitly asks for a different path.

This branch is about porting and validating Xvideo on iOS. macOS app packaging, macOS Computer Use acceptance, and macOS GitHub Release updates are not default gates here. Run macOS-specific checks only when the user asks for them or when a change intentionally touches macOS-only behavior.

## Always Start Here

1. Inspect first.
   - Run `git status -sb`.
   - Check the current branch, remote, recent commits, connected-device context, and files relevant to the request.
   - Preserve unrelated user changes. Never use destructive git commands or revert user work unless explicitly requested.
2. Read context before editing.
   - Read `Docs/FeatureList.md` for the current product surface.
   - Read `Docs/Architecture.md` before changing structure, data flow, packaging, signing, install, or release behavior.
   - Read nearby SwiftUI/UIKit/domain files before planning code changes.
3. Use scoped edits.
   - Keep changes limited to the requested behavior and its direct documentation, tests, packaging, and acceptance artifacts.
   - Use existing SwiftUI/UIKit and Clean Architecture patterns.
   - Use `apply_patch` for manual edits.

## Project-Local Skills

Each large workflow phase must call the matching project-local skill. "Call" means explicitly follow that skill's checklist and name it in the working notes or final summary when it materially shaped the work.

### Skill: Xvideo iOS Feature Intake

Use this skill whenever the user asks for a new iPhone feature, iOS UI behavior, playback behavior, signing/install workflow change, or bug fix with user-visible impact.

Purpose:
- Turn the user's request into a maintained iOS product requirement before implementation.
- Keep `Docs/FeatureList.md` as the source of truth for implemented and planned behavior on the `ios` branch.

Steps:
1. Compare the request with the current code and `Docs/FeatureList.md`.
2. Write a short requirement analysis:
   - What user problem is being solved on iPhone.
   - Which current behavior already exists.
   - Which behavior must change.
   - Constraints from `Docs/Architecture.md`, iOS signing, and physical-device testing.
3. Update `Docs/FeatureList.md` before or alongside the code change:
   - Add the requested iOS behavior to the right feature area.
   - Mark planned, in-progress, blocked, or implemented behavior clearly when acceptance is not complete.
   - Remove or adjust stale entries only when the code actually changed.
4. Create or update a feature acceptance document under `Docs/Acceptance/`.
   - Use a stable name such as `Docs/Acceptance/<feature-slug>.md`.
   - Include requirement summary, scope, prerequisites, device/signing assumptions without private source details, and a checklist that maps directly back to `Docs/FeatureList.md`.

### Skill: Xvideo iOS Plan-First Implementation

Use this skill for every code or script change on the `ios` branch.

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
   - SwiftUI state and iPhone user interaction belong in `Presentation`.
   - App assembly belongs in `App`.
4. Compile after code edits.
   - For iOS app code, run:
     ```bash
     swift build --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
     ```
   - For package/shared changes where host compilation is useful, `swift build` may also be run, but it is not a required iOS branch gate.
   - Fix all compiler errors before testing or packaging.
5. Add focused checks for changed logic when practical.
   - Prefer direct tests or lightweight command checks for domain/data logic.
   - For UI/player/source/search/persistence/download workflows, the iPhone acceptance skill below is required.

### Skill: Xvideo iPhone Acceptance

Use this skill after any iPhone user-visible feature, UI behavior, player behavior, source-management behavior, search/browse behavior, persistence behavior, download behavior, or bug fix.

Purpose:
- Validate through the real iOS build, signing, install, and launch path.
- Produce a pass/fail/blocked acceptance result tied to `Docs/FeatureList.md`.

Steps:
1. Prepare the signed iPhone app.
   - Prefer the Xcode automatic-signing path:
     ```bash
     IOS_DEVICE_UDID="<iphone-udid>" Scripts/build_ios_xcode_app.sh
     ```
   - The script generates a temporary Xcode project under `.build/ios-xcode`, signs with the local Apple Development team, and copies the signed app to `.build/ios-device/Xvideo.app`.
   - Use `Scripts/build_ios_app.sh` only for unsigned, manual-signing, or ad-hoc install probing.
2. Install and launch on the paired iPhone.
   - Use the CoreDevice identifier with:
     ```bash
     IOS_DEVICE_ID="<paired-device-id>" Scripts/install_ios_app.sh
     ```
   - If needed, list devices with `xcrun devicectl list devices` and destinations with `xcrun xcodebuild -showdestinations`.
   - If launch fails because iOS has not trusted the Apple Development profile, state that exact blocker and ask the user to trust it on the phone. Do not treat this as a code failure.
3. Verify command-side device state.
   - Confirm the app is installed:
     ```bash
     xcrun devicectl device info apps --device "<paired-device-id>"
     ```
   - Confirm the app process is running when launch succeeds:
     ```bash
     xcrun devicectl device info processes --device "<paired-device-id>"
     ```
4. Verify user-visible flows.
   - Use available iOS simulator/browser/UI tools only when they represent the requested behavior well.
   - For physical iPhone-only flows where UI automation is unavailable, ask the user for the smallest necessary on-phone confirmation and mark that checklist item as blocked or pending until observed.
   - Do not substitute macOS Computer Use for iPhone UI acceptance on this branch.
   - Do not record concrete private data source names, source URLs, credentials, or private testing details in committed docs or release notes.
5. Update the acceptance document under `Docs/Acceptance/`.
   - Mark each checklist item as pass, fail, blocked, pending, or not applicable.
   - Include concise evidence: build command, signed app path, install/launch command, device-state command, tested workflow, and observed result.
   - End with a clear conclusion: `Accepted`, `Rejected`, or `Blocked`.
6. If acceptance fails:
   - Fix the issue.
   - Rebuild with `Scripts/build_ios_xcode_app.sh`.
   - Reinstall and relaunch with `Scripts/install_ios_app.sh`.
   - Repeat the relevant acceptance pass.

### Skill: Xvideo iOS Documentation

Use this skill whenever iOS behavior, UI, setup, signing, install, source handling, screenshots, build instructions, or usage changes.

Purpose:
- Keep user-facing docs honest and minimal.

Steps:
1. Check `README.md` for every change.
   - Update it for user-visible iOS feature, UI, setup, signing, source, screenshot, build, install, or usage changes.
   - If no README update is needed, say so in the final response.
2. Keep `README.en.md` aligned when the same user-visible information exists there.
3. Keep `Docs/FeatureList.md` aligned with the final iOS behavior after implementation.
4. Keep acceptance docs factual and free of private source details.

### Skill: Xvideo iOS Package, GitHub, and Release

Use this skill after code, script, or app behavior changes. For docs-only changes, commit and push are still required.

Purpose:
- Keep the `ios` branch pushed and reproducible without accidentally shipping macOS release artifacts.

Steps:
1. Confirm verification is complete.
   - iOS compile passed when code changed.
   - `Scripts/build_ios_xcode_app.sh` passed when signing/install behavior or user-visible iPhone behavior changed.
   - `Scripts/install_ios_app.sh` passed when a paired iPhone is available and trusted.
   - Acceptance document has a final conclusion.
2. Commit and push.
   - Stage only task-related files.
   - Commit locally with a clear message using the `Docs/Architecture.md` commit type guidance.
   - Push to GitHub after the commit succeeds.
3. Do not update the macOS GitHub Release from the `ios` branch by default.
   - iOS signed `.app` bundles are local development artifacts unless the user explicitly asks for an iOS distribution package.
   - If the user asks for packaging/distribution, document the signing/export method and avoid including private source details.

### Skill: Xvideo iOS Final Gate

Use this skill before every final response.

Purpose:
- Make sure the repository is left in a clear, verifiable iOS branch state.

Steps:
1. Run `git status -sb`.
2. Confirm whether the branch is ahead/behind the remote.
3. Confirm README status:
   - Updated, or
   - Not needed, with a short reason.
4. Confirm iOS build/test status:
   - Include commands run and outcomes.
   - State any skipped checks and why.
   - Call out physical iPhone UI items that remain blocked because automation is unavailable.
5. Confirm release status:
   - Usually not needed on the `ios` branch.
   - State explicitly if no macOS release was updated.

## End-to-End Workflow

For a normal iOS feature request, use the skills in this order:

1. `Xvideo iOS Feature Intake`
   - Analyze the requirement against current code.
   - Maintain `Docs/FeatureList.md`.
   - Create or update `Docs/Acceptance/<feature-slug>.md`.
2. `Xvideo iOS Plan-First Implementation`
   - Use Codex's plan mechanism.
   - Implement against the plan.
   - Run the iOS compile command.
3. `Xvideo iPhone Acceptance`
   - Build a signed iPhone app with `Scripts/build_ios_xcode_app.sh`.
   - Install and launch `.build/ios-device/Xvideo.app` with `Scripts/install_ios_app.sh`.
   - Verify installed/running state with `devicectl`.
   - Use iPhone-side confirmation or available iOS UI tooling for the actual user flow.
   - Update the acceptance document with pass/fail/blocked conclusion.
4. `Xvideo iOS Documentation`
   - Update `README.md` and `README.en.md` when user-visible iOS behavior or setup changed.
   - Reconcile `Docs/FeatureList.md` with the final behavior.
5. `Xvideo iOS Package, GitHub, and Release`
   - Commit and push task-related files.
   - Do not create or update a macOS GitHub Release unless explicitly requested.
6. `Xvideo iOS Final Gate`
   - Report working tree, push status, README status, iOS verification, physical-device acceptance status, and release status.

## Lightweight Exceptions

- Documentation-only changes:
  - Inspect first.
  - Edit docs.
  - Check whether README changes are needed.
  - Commit and push.
  - Skip iOS build/install unless the docs affect build, signing, install, or release instructions.
- Pure internal refactors:
  - Still use plan-first implementation.
  - Run the iOS compile command.
  - Run focused checks.
  - Use iPhone acceptance only if behavior can change from the user's perspective.
- Emergency fixes:
  - Keep the plan short, but still maintain `Docs/FeatureList.md` and acceptance docs if the fix changes iPhone user-visible behavior.

## Project Rules

- App name and UI brand: `Xvideo`.
- Signed iPhone app path: `.build/ios-device/Xvideo.app`.
- iOS automatic-signing build script: `Scripts/build_ios_xcode_app.sh`.
- iOS manual/ad-hoc build script: `Scripts/build_ios_app.sh`.
- iOS install/launch script: `Scripts/install_ios_app.sh`.
- macOS app path `.build/app/Xvideo.app` and `Scripts/build_app.sh` are not default gates on the `ios` branch.
- Never include concrete private data source names, source URLs, credentials, device owner personal details, or private testing details in committed docs or release notes.
- Never use destructive git commands or revert user changes unless explicitly requested.
