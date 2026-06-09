# iPhone App Acceptance

Status note: this document records the historical first iPhone app acceptance pass. Future iOS acceptance should follow the risk-based workflow in `AGENTS.md` and `Docs/WorkflowSkills/IPhoneAcceptance.md`; non-iOS build, package, UI acceptance, and release checks are not default gates on the `ios` branch.

## Requirement Summary

Create an iPhone application shape for Xvideo on the `ios` branch so the app can run on a phone while reusing the existing media API, browsing, detail, playback, favorites, continue-watching, persistence, and download foundations.

## Scope

- Add iOS platform support while preserving shared code boundaries.
- Provide a touch-first iPhone interface for source management, browsing, search, favorites, continue watching, movie details, playback source selection, and episode playback.
- Preserve private-source handling: acceptance notes must not include concrete source names, source URLs, credentials, or private test data.
- Prepare the project for installation on a paired iPhone when signing is available.

## Prerequisites

- Xcode and iOS SDK are installed.
- A paired iPhone is connected and available to developer tools.
- Installing to a physical iPhone requires a valid Apple Development signing identity or Xcode automatic signing team.
- Test media data uses user-provided private API details that are intentionally not recorded here.

## Checklist

- [x] `Docs/FeatureList.md` documents the iPhone app surface and platform limits.
- [x] Shared SwiftPM host build was checked during the original port; future non-iOS checks are not default iOS acceptance gates unless the user explicitly asks for non-iOS behavior.
- [x] iOS code compiles for an iOS destination.
- [x] iPhone UI launches to a touch-first tab interface.
- [ ] Video sources can be added, tested, enabled, and deleted from the phone UI.
- [ ] Latest updates and categories can be browsed from the phone UI.
- [ ] Search can load keyword results from the phone UI.
- [ ] Movie detail shows poster, metadata, summary, favorite action, playback sources, and episodes.
- [ ] Selecting an episode opens native or web playback as appropriate.
- [ ] Player fullscreen opens from the iPhone player controls and can be dismissed back to detail.
- [ ] Favorites and continue-watching flows remain accessible on iPhone.
- [x] If a physical iPhone install is blocked, the blocker is recorded with concrete evidence.

## Evidence

- Historical evidence: `swift build` passed for the host SwiftPM target during the original port. This is not a default future iOS acceptance gate.
- `swift build --triple arm64-apple-ios17.0-simulator --sdk $(xcrun --sdk iphonesimulator --show-sdk-path)` passed.
- `swift build --triple arm64-apple-ios17.0 --sdk $(xcrun --sdk iphoneos --show-sdk-path)` passed.
- `Scripts/build_ios_app.sh` generated `.build/ios-device/Xvideo.app`.
- `IOS_AD_HOC_SIGN=1 Scripts/build_ios_app.sh` generated an ad-hoc signed temporary app bundle for install probing.
- `Scripts/build_ios_xcode_app.sh` generated a temporary Xcode iOS app project and produced a signed `.build/ios-device/Xvideo.app`.
- `xcrun devicectl list devices` reported a paired iPhone as available.
- After Xcode account login, `security find-identity -v -p codesigning` reported an Apple Development identity.
- The Xcode signed app includes an embedded provisioning profile for `com.seeker.xvideo`.
- `IOS_ALLOW_AD_HOC=1 IOS_DEVICE_ID=<paired-device-id> Scripts/install_ios_app.sh` reached the device install service, then failed with `Developer Mode is disabled`.
- `xcrun devicectl device install app --device <paired-device-id> .build/ios-device/Xvideo.app` installed the signed app on the paired iPhone.
- `IOS_DEVICE_ID=<paired-device-id> Scripts/install_ios_app.sh` installed and launched `com.seeker.xvideo` successfully after the Apple Development profile was trusted on the phone.
- `xcrun devicectl device info apps --device <paired-device-id>` listed `Xvideo com.seeker.xvideo 1.0`.
- `xcrun devicectl device info processes --device <paired-device-id>` listed the running `Xvideo.app/Xvideo` process.
- iPhone fullscreen playback code compiled for the device target, but physical click-through of selecting an episode and tapping fullscreen has not been directly observed through automation.

## Current Run: 2026-06-09

- `swift build --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"` passed for the iPhoneOS target.
- `xcrun devicectl list devices` reported a paired iPhone as available.
- `security find-identity -v -p codesigning` reported a valid Apple Development identity.
- A user-provided test media source was checked at the network level without recording its concrete URL; the source returned a non-empty XML response with playable catalog items.
- `IOS_DEVICE_UDID=<paired-device-id> Scripts/build_ios_xcode_app.sh` produced a signed `.build/ios-device/Xvideo.app`.
- `IOS_DEVICE_ID=<paired-device-id> Scripts/install_ios_app.sh` installed `com.seeker.xvideo` on the paired iPhone.
- `xcrun devicectl device info apps --device <paired-device-id>` listed `Xvideo com.seeker.xvideo 1.0`.
- Launch was retried with `xcrun devicectl device process launch --device <paired-device-id> com.seeker.xvideo`, but iOS rejected each request because the device was locked.
- Full phone UI acceptance for source add/test/enable/delete, library browsing, search, detail, playback, fullscreen, favorites, continue watching, downloads, and persistence remains blocked until the iPhone is unlocked and available for interaction.

## Continued Run: 2026-06-09

- After the iPhone was unlocked, `xcrun devicectl device process launch --device <paired-device-id> com.seeker.xvideo` launched the installed app successfully.
- `xcrun devicectl device info processes --device <paired-device-id>` listed the running `Xvideo.app/Xvideo` process.
- iOS Simulator UI acceptance was run on an iPhone simulator with the user-provided test media source, without recording the concrete source URL.
- Source management passed in Simulator: add, test, enable, switch active source, and delete a non-active source.
- Library passed in Simulator: initial empty source state, source-backed categories, category browsing, list rows, and continued list scrolling.
- Search passed in Simulator: an ASCII keyword search returned source-backed results and result scrolling worked.
- Detail and playback passed in Simulator: detail metadata, summary, playback source menu, episode grid, previous/next episode controls, selected episode state, web/native player selection path, fullscreen presentation, and fullscreen dismissal.
- Favorites and continue watching passed in Simulator: favorite toggled to saved state, favorite list opened the movie, playback state wrote continue-watching entries, and continue-watching rows plus delete controls were visible.
- Download acceptance initially failed in Simulator because the URLSession temporary download file was moved after the delegate callback returned. The download manager was fixed to copy the temporary file to a stable local location before updating UI state.
- After the fix, `swift build --triple arm64-apple-ios17.0 --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"` passed again.
- The fixed Simulator build completed and download retest passed: the download shelf showed `已完成`, and the downloaded file existed under the app `Documents/Xvideo` directory.
- The fixed app was rebuilt for the paired iPhone with `IOS_DEVICE_UDID=<paired-device-id> Scripts/build_ios_xcode_app.sh`.
- `IOS_DEVICE_ID=<paired-device-id> Scripts/install_ios_app.sh` installed and launched the fixed app on the paired iPhone.
- `xcrun devicectl device info apps --device <paired-device-id>` listed `Xvideo com.seeker.xvideo 1.0`, and `xcrun devicectl device info processes --device <paired-device-id>` listed the running app process.

## Conclusion

Blocked for complete iPhone playback click-through acceptance because physical device UI automation is unavailable in this session. The iOS code path compiles, the Xcode automatic-signing path produces a provisioned app bundle, and the signed app installs and launches on the paired iPhone.

Latest run conclusion: Blocked because the signed app installed successfully, but the physical iPhone was locked and iOS denied launch requests before UI acceptance could begin.

Latest continued run conclusion: Accepted for current practical coverage. The fixed app compiles for iPhoneOS, installs and launches on the paired physical iPhone, and the full user-flow matrix passed in iOS Simulator. Residual risk: physical iPhone touch-through UI automation is not available, so simulator UI evidence is used for detailed interaction coverage while the physical device evidence covers install and launch.
