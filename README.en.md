# xvideo

[中文](README.md) | [English](README.en.md)

xvideo is a native macOS video client built with SwiftUI. It fetches video lists, details, and playback sources from a media API, then presents them in a desktop-style browsing and playback experience.

The project is focused on everyday watching: browsing categories, searching titles, reading details, switching episodes, saving favorites, and playing videos inside the app.

## Preview

The screenshot below shows the app layout. Specific video information in the image has been blurred.

![xvideo app preview with blurred video details](Docs/images/app-preview-blurred.png)

## Features

- Browse latest updates and video categories
- Search by title, actor, or keyword
- View poster, summary, region, year, cast, director, and update status
- Switch between multiple playback sources, including m3u8 and web-player sources
- Jump to the next episode from the player
- Favorite videos and reopen them quickly from My Favorites
- Download available mp4 resources to `~/Downloads/xvideo`

## Run

The project uses Swift Package Manager and requires macOS 14 or later.

```bash
swift run xvideo
```

## Build The macOS App

```bash
./Scripts/build_app.sh
open .build/app/xvideo.app
```

The build script creates:

```text
.build/app/xvideo.app
```

## Project Structure

```text
Sources/xvideo
├── App                  # App entry point and dependency setup
├── Presentation         # SwiftUI views and view models
├── Domain               # Models, protocols, and playback parsing
├── Data                 # API client and repository implementation
├── Infrastructure       # Downloads, favorites, and local system features
└── Shared               # Shared extensions
```

More architecture notes are available in [Docs/Architecture.md](Docs/Architecture.md).

## Notes

The app depends on a third-party media source API. Playback availability can vary depending on the resource, network environment, and source restrictions. If one source does not play, try switching to another playback source first.
