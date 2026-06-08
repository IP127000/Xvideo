# Xvideo

[中文](README.md) | [English](README.en.md)

The `ios` branch of Xvideo is the native iOS app development branch, with iPhone as the default touch-first product surface. It fetches video lists, details, and playback sources from user-configured media APIs, then reuses the same source, library, detail, playback, favorites, and continue-watching foundations.

The project is focused on everyday phone watching: browsing categories, searching titles, reading details, switching episodes, tracking local watch progress, saving favorites, and playing videos inside the iPhone player. The repository still keeps the macOS target and shared SwiftUI code, but macOS packaging, acceptance, and release work are not default gates for this branch.

## Preview

The current preview image comes from the shared macOS interface and mainly shows the library/detail foundation. New work on the `ios` branch should treat the iPhone tab interface, touch detail screen, and player as the product source of truth.

![Xvideo macOS app preview](Docs/images/app-preview-blurred.png)

## Features

- Use the iPhone tab interface for Library, Search, Favorites, Continue Watching, and Video Sources
- Browse latest updates and video categories
- Use the iPhone detail screen for posters, summary, favorites, playback sources, and episodes
- Prioritize favorites in Featured Picks, and browse the full catalog in two-row shuffle batches
- Search by title, actor, or keyword
- View poster, summary, region, year, cast, director, and update status
- Ships with no built-in data source; add your own collection API before browsing
- Switch between multiple data and playback sources, including JSON, XML, and flat XML category APIs
- Jump to the previous or next episode from the player
- Rewind or fast-forward 15 seconds
- Track local watch progress while episodes play, then resume the last episode and playback time from Continue Watching
- Favorite videos with their source attached, then continue watching from My Favorites
- Save iPhone downloads in the app Documents `Xvideo` folder; the auxiliary macOS target still saves to `~/Downloads/Xvideo`

## Run

The project uses Swift Package Manager. The `ios` branch defaults to developing and validating the iPhone app, which requires iOS 17 or later.

## Build The iPhone App Bundle

For physical-device installs, prefer the Xcode automatic-signing script. It generates a temporary Xcode project, signs with the local Apple Development certificate and team, then copies the result to `.build/ios-device/Xvideo.app`:

```bash
IOS_DEVICE_UDID="<iphone-udid>" ./Scripts/build_ios_xcode_app.sh
IOS_DEVICE_ID="<paired-device-id>" ./Scripts/install_ios_app.sh
```

If iOS reports that the developer app is not trusted, trust the matching Apple Development profile on the phone in Settings > General > VPN & Device Management before launching again.

The SwiftPM packaging path is still available for unsigned, manually signed, or install-probing bundles:

```bash
./Scripts/build_ios_app.sh
```

The script creates:

```text
.build/ios-device/Xvideo.app
```

Manual physical iPhone signing requires a valid Apple Development signing certificate in the local keychain and a provisioning profile that matches `IOS_BUNDLE_ID`:

```bash
IOS_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" \
IOS_PROVISIONING_PROFILE="/path/to/profile.mobileprovision" \
./Scripts/build_ios_app.sh

IOS_DEVICE_ID="<paired-device-id>" ./Scripts/install_ios_app.sh
```

For temporary install probing, ad-hoc signing can be attempted. The phone must have Developer Mode enabled, and iOS may still require a real provisioning profile:

```bash
IOS_AD_HOC_SIGN=1 ./Scripts/build_ios_app.sh
IOS_ALLOW_AD_HOC=1 IOS_DEVICE_ID="<paired-device-id>" ./Scripts/install_ios_app.sh
```

## Auxiliary macOS Run Path

The macOS target is still useful for shared-code debugging, but it is not the default acceptance or release path for the `ios` branch.

```bash
swift run Xvideo
```

## Auxiliary macOS Build Path

Use this only when desktop target verification is explicitly needed:

```bash
./Scripts/build_app.sh
open .build/app/Xvideo.app
```

## Project Structure

```text
Sources/Xvideo
├── App                  # App entry point and dependency setup
├── Presentation         # SwiftUI views and view models
├── Domain               # Models, protocols, and playback parsing
├── Data                 # API client and repository implementation
├── Infrastructure       # Downloads, favorites, and local system features
└── Shared               # Shared extensions
```

More architecture notes are available in [Docs/Architecture.md](Docs/Architecture.md).

## Notes

The app ships with no built-in data source, and all catalog data comes from user-configured APIs. Playback availability can vary depending on the resource, network environment, and source restrictions. The app validates a data source before enabling it, and keeps the current source active if validation fails. If one playback source does not play, try switching to another playback source first.
