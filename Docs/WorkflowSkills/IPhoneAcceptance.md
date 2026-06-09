# Xvideo iPhone Acceptance Skill

Use this skill after meaningful iPhone user-visible changes and after signing/install workflow changes.

## Purpose

- Validate the iOS build, Simulator user-flow path, physical iPhone install path, and cleanup state when the risk justifies it.
- Produce pass, fail, blocked, pending, or not-applicable acceptance status tied to `Docs/FeatureList.md`.
- Keep physical-device blockers distinct from code failures.
- Keep functional validation on iOS Simulator by default, and keep physical iPhone validation to signed install unless explicitly requested otherwise.

## Procedure

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
   The script generates `.build/ios-xcode`, signs with the local Apple Development team, and copies the app to `.build/ios-device/Xvideo.app`.
4. Install on the paired iPhone when available. The install script may launch the app; use launch only as command-side smoke evidence:
   ```bash
   IOS_DEVICE_ID="<paired-device-id>" Scripts/install_ios_app.sh
   ```
5. Verify command-side device state after install, and process state only when launch was part of the command path:
   ```bash
   xcrun devicectl device info apps --device "<paired-device-id>"
   xcrun devicectl device info processes --device "<paired-device-id>"
   ```
6. Mark each checklist item.
   - Use pass, fail, blocked, pending, or not applicable.
   - For physical-device-only checks where automation is unavailable, ask the user for the smallest necessary on-phone confirmation.
7. Update the acceptance document when one exists.
   - Include concise evidence: command, outcome, signed app path, device-state result, tested workflow, and observed result.
   - End with `Accepted`, `Rejected`, or `Blocked`.
8. If acceptance fails because of code behavior, fix and repeat the relevant build, Simulator validation, install, and acceptance checks.
9. Cleanup after validation.
   - Stop the app under test.
   - Shut down or close the Simulator used for validation.
   - Stop browser mirrors, `serve-sim`, local mock servers, and helper processes.
   - Remove temporary source data, screenshots, logs, DerivedData, generated projects, and build products unless they are explicit release artifacts requested by the user.

## Blockers

Record these as blocked acceptance rather than code failures:

- No paired device.
- Device locked or disconnected.
- Developer Mode disabled.
- Developer profile not trusted.
- Missing signing identity or provisioning.
- Simulator unavailable or unable to expose UI hierarchy for a Simulator-required flow.
- UI automation unavailable for an explicitly requested physical-device-only flow.

## Skip Rules

- Do not use desktop Computer Use or desktop UI behavior as a substitute for iPhone acceptance.
- Do not require physical phone UI acceptance for tiny copy changes, pure internal refactors, or simulator-faithful UI changes.
- Do not record concrete private source names, source URLs, credentials, personal device details, or private test data.
- Do not keep temporary validation files after closeout unless they are explicit release artifacts.

## Output

Report the Simulator validation surface, physical install surface, commands run, observed result, cleanup performed, checklist status, blockers, and residual risk.
