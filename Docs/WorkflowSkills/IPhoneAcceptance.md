# Xvideo iPhone Acceptance Skill

Use this skill after meaningful iPhone user-visible changes and after signing/install workflow changes.

## Purpose

- Validate the real iOS build, signing, install, launch, and user-flow path when the risk justifies it.
- Produce pass, fail, blocked, pending, or not-applicable acceptance status tied to `Docs/FeatureList.md`.
- Keep physical-device blockers distinct from code failures.

## Procedure

1. Decide the acceptance surface.
   - Simulator or iOS UI tooling is acceptable when it faithfully represents the requested iPhone behavior.
   - Physical iPhone acceptance is preferred for playback, web playback, signing/install, persistence across launches, downloads, and source-management flows when a paired trusted device is available.
2. Prepare the signed iPhone app when a real device check is needed:
   ```bash
   IOS_DEVICE_UDID="<iphone-udid>" Scripts/build_ios_xcode_app.sh
   ```
   The script generates `.build/ios-xcode`, signs with the local Apple Development team, and copies the app to `.build/ios-device/Xvideo.app`.
3. Install and launch on the paired iPhone when available:
   ```bash
   IOS_DEVICE_ID="<paired-device-id>" Scripts/install_ios_app.sh
   ```
4. Verify command-side device state when launch succeeds:
   ```bash
   xcrun devicectl device info apps --device "<paired-device-id>"
   xcrun devicectl device info processes --device "<paired-device-id>"
   ```
5. Verify the user-visible flow.
   - Cover the actual tap, input, scroll, playback, persistence, download, or source-management path.
   - For physical-device-only checks where automation is unavailable, ask the user for the smallest necessary on-phone confirmation.
   - Mark each checklist item pass, fail, blocked, pending, or not applicable.
6. Update the acceptance document when one exists.
   - Include concise evidence: command, outcome, signed app path, device-state result, tested workflow, and observed result.
   - End with `Accepted`, `Rejected`, or `Blocked`.
7. If acceptance fails because of code behavior, fix and repeat the relevant build, install, launch, and acceptance checks.

## Blockers

Record these as blocked acceptance rather than code failures:

- No paired device.
- Device locked or disconnected.
- Developer Mode disabled.
- Developer profile not trusted.
- Missing signing identity or provisioning.
- UI automation unavailable for a physical-device-only flow.

## Skip Rules

- Do not use desktop Computer Use or macOS UI behavior as a substitute for iPhone acceptance.
- Do not require physical-device acceptance for tiny copy changes, pure internal refactors, or simulator-faithful low-risk UI changes.
- Do not record concrete private source names, source URLs, credentials, personal device details, or private test data.

## Output

Report the acceptance surface used, commands run, observed result, checklist status, blockers, and residual risk.
