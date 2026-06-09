# Xvideo

[中文](README.md) | [English](README.en.md)

Xvideo is a Web media client built with React, Vite, and TypeScript. It loads movie lists, details, and playback URLs from user-configured media collection APIs.

The app does not ship with any built-in source. On first use, add your own collection API. Search, playback, and download quality depend on that source.

## Features

- Browse latest updates, root categories, and child categories
- Dark cinema-style Web workspace with media navigation and playback/detail views
- Featured movies prioritize favorites; all movies can rotate in batches
- Search by title, actor, or keyword
- Filter category browsing by type, year, and area
- View posters, summaries, metadata, scores, update status, playback sources, and episodes
- Add, test, enable, switch, and delete multiple user sources
- Supports JSON, XML, and flat XML category APIs
- Direct playback through browser video, m3u8 through hls.js, and `/share/` web players through iframe/new-window fallback
- Previous/next episode and 15-second skip controls
- Continue-watching records include source, playback source, episode, position, and timestamp
- Favorites keep source metadata for source-aware restore
- Browser downloads for direct file resources
- Sources, favorites, watch progress, and preview cache persist in localStorage
- Vite dev/preview includes a local proxy for source APIs, playback URL resolution, and media proxying

## Run

```bash
npm install
npm run dev
```

Default local URL:

```text
http://127.0.0.1:5173
```

## Build And Preview

```bash
npm test
npm run build
npm run preview
```

Build output:

```text
dist/
```

## Structure

```text
src
├── App.tsx
├── appContext.tsx
├── components
├── hooks
├── services
├── styles.css
└── types.ts
```

Development workflow and verification rules live in [AGENTS.md](AGENTS.md) and [Docs/Workflow/](Docs/Workflow/).

## Web Notes

- The Web app relies on the local Vite proxy during development/preview. Static deployments need an equivalent proxy for common CORS-restricted sources.
- Browsers cannot force downloads into `~/Downloads/Xvideo` or reveal files in Finder; downloads use the browser's default behavior.
- Playback depends on source availability, browser media support, CORS, iframe policy, and codec support.
