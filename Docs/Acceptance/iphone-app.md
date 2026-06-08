# iPhone App Acceptance

## Requirement Summary

Create an iPhone application shape for Xvideo on the `ios` branch so the app can run on a phone while reusing the existing media API, browsing, detail, playback, favorites, continue-watching, persistence, and download foundations.

## Scope

- Add iOS platform support without removing the existing macOS app behavior.
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
- [x] macOS build still succeeds with `swift build`.
- [x] iOS code compiles for an iOS destination.
- [ ] iPhone UI launches to a touch-first tab interface.
- [ ] Video sources can be added, tested, enabled, and deleted from the phone UI.
- [ ] Latest updates and categories can be browsed from the phone UI.
- [ ] Search can load keyword results from the phone UI.
- [ ] Movie detail shows poster, metadata, summary, favorite action, playback sources, and episodes.
- [ ] Selecting an episode opens native or web playback as appropriate.
- [ ] Favorites and continue-watching flows remain accessible on iPhone.
- [x] If a physical iPhone install is blocked, the blocker is recorded with concrete evidence.

## Evidence

- `swift build` passed for the macOS SwiftPM target.
- `swift build --triple arm64-apple-ios17.0-simulator --sdk $(xcrun --sdk iphonesimulator --show-sdk-path)` passed.
- `swift build --triple arm64-apple-ios17.0 --sdk $(xcrun --sdk iphoneos --show-sdk-path)` passed.
- `Scripts/build_ios_app.sh` generated `.build/ios-device/Xvideo.app`.
- `IOS_AD_HOC_SIGN=1 Scripts/build_ios_app.sh` generated an ad-hoc signed temporary app bundle for install probing.
- `Scripts/build_app.sh` generated `.build/app/Xvideo.app`.
- The macOS app launched and displayed the main Xvideo window through Computer Use.
- `xcrun devicectl list devices` reported a paired iPhone as available.
- `security find-identity -v -p codesigning` reported `0 valid identities found`.
- `Scripts/install_ios_app.sh` stopped before install because `.build/ios-device/Xvideo.app` has no embedded provisioning profile.
- `IOS_ALLOW_AD_HOC=1 IOS_DEVICE_ID=<paired-device-id> Scripts/install_ios_app.sh` reached the device install service, then failed with `Developer Mode is disabled`.
- iPhone click-through acceptance is blocked until Developer Mode is enabled on the phone. A valid Apple Development signing identity and matching provisioning profile may still be required after that for non-ad-hoc installs.

## Conclusion

Blocked for physical iPhone acceptance by Developer Mode being disabled on the phone. The iOS code path compiles for simulator and device destinations, and both unsigned and ad-hoc signed iPhone app bundles can be generated locally.
