# Xvideo

[中文](README.md) | [English](README.en.md)

Xvideo is a native macOS anime-tracking and video client built with SwiftUI. It fetches video lists, details, and playback sources from user-configured media APIs, then presents them in a desktop-style browsing and playback experience.

The project is focused on an Animeko-like find, track, and watch flow: browse updates, search by tags, review a local schedule, switch episodes, track local progress, manage offline cache tasks, and tune playback settings.

## Preview

The main window now uses Animeko-style tracking navigation: Home, Discover, Schedule, Continue Watching, Favorites, Offline Cache, and Settings on the left, with update feeds, tag filters, schedules, cache management, or playback details on the right.

![Xvideo macOS app preview](Docs/images/app-preview-blurred.png)

## Features

- Use Animeko-style navigation for Home, Discover, Schedule, Continue Watching, Favorites, Offline Cache, and Settings
- Show Continue Watching, today/weekly updates, recent updates, tags, and category entry points on Home
- Discover by title, actor, director, tag, year, region, language, and category
- Build a local schedule from source update timestamps, with graceful fallback when exact broadcast data is unavailable
- View poster, summary, region, year, cast, director, and update status
- Ships with no built-in data source; add your own collection API before browsing
- Switch between multiple data and playback sources, including JSON, XML, and flat XML category APIs, with visible source health
- Use source cards, episode state, last-watched markers, and next-episode suggestions on the detail page
- Jump to the previous or next episode, configure seek intervals, and close the playback window with Esc
- Toggle a basic danmaku overlay, import local danmaku text, and cache the current episode from the player
- Track local watch progress while episodes play, then resume the last episode and playback time from Continue Watching
- Favorite videos with their source attached, then click or double-click them in My Favorites to continue watching
- Manage direct-link offline cache tasks with pause, cancel, retry, delete, and Finder reveal actions
- Configure data sources, playback, danmaku, cache, appearance, and local data import/export in Settings

## Run

The project uses Swift Package Manager and requires macOS 14 or later.

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
