# Xvideo

[中文](README.md) | [English](README.en.md)

Xvideo is a native macOS video client built with SwiftUI. It fetches video lists, details, and playback sources from user-configured media APIs, then presents them in a desktop-style browsing and playback experience. The `ios` branch also adds an iPhone touch interface that reuses the same source, library, detail, playback, favorites, and continue-watching foundations.

The project is focused on everyday watching: browsing categories, searching titles, reading details, switching episodes, tracking local watch progress, saving favorites, and playing videos inside the app.

## Preview

The main window now uses a two-column cinematic layout: media library, categories, and source management on the left; the upper-right area shows the selected title details, with featured picks and the full catalog below. Clicking a title card opens quick details and refreshes the upper detail panel; double-click a card or choose Start Playback to enter the dedicated player page.

![Xvideo macOS app preview](Docs/images/app-preview-blurred.png)

## Features

- Browse latest updates and video categories
- Use a two-column cinematic interface with an inline detail panel and a separate playback page
- Prioritize favorites in Featured Picks, and browse the full catalog in two-row shuffle batches
- Search by title, actor, or keyword
- View poster, summary, region, year, cast, director, and update status
- Ships with no built-in data source; add your own collection API before browsing
- Switch between multiple data and playback sources, including JSON, XML, and flat XML category APIs
- Jump to the previous or next episode from the player
- Rewind or fast-forward 15 seconds, and close the playback window with Esc
- Track local watch progress while episodes play, then resume the last episode and playback time from Continue Watching
- Favorite videos with their source attached, then click or double-click them in My Favorites to continue watching
- Download available mp4 resources to `~/Downloads/Xvideo`
- Use the iPhone tab interface for Library, Search, Favorites, Continue Watching, and Video Sources

## Run

The project uses Swift Package Manager. The macOS app requires macOS 14 or later, and the iPhone app requires iOS 17 or later.

```bash
swift run Xvideo
```

## Build The macOS App

```bash
./Scripts/build_app.sh
open .build/app/Xvideo.app
```

The build script creates:

```text
.build/app/Xvideo.app
```

## Build The iPhone App Bundle

```bash
./Scripts/build_ios_app.sh
```

The script creates:

```text
.build/ios-device/Xvideo.app
```

Installing on a physical iPhone requires a valid Apple Development signing certificate in the local keychain and a provisioning profile that matches `IOS_BUNDLE_ID`:

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
