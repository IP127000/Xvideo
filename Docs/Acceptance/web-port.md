# Xvideo Web Port Acceptance

## Requirement Summary

Port the current `main` branch product behavior to a Web branch and update the repository workflow from macOS app development to Web development.

## Scope

- React/Vite Web app loads and renders the Xvideo workspace.
- User-configured sources can be added, tested, enabled, switched, and deleted.
- JSON/XML media APIs are parsed through the local Vite proxy.
- Browsing, category preview, search, filter, detail loading, playback source parsing, favorites, continue-watching, and downloads are represented in the Web UI.
- Workflow docs, README, and feature docs describe Web development and verification.

## Test Data Assumptions

- No private media source names, URLs, credentials, or private test content are recorded here.
- Acceptance can verify first-load, empty-source state, source manager UI, browser rendering, tests, and build without a private source.
- Source-backed playback, search, favorites, continue-watching, and category behavior was also checked with a user-configured XML source; concrete source names, URLs, and media titles are intentionally omitted.

## Checklist

- [x] `npm test` passes.
- [x] `npm run build` passes.
- [x] Local dev server starts.
- [x] Browser loads the app at the local URL without framework error overlays.
- [x] First meaningful screen renders with brand, navigation, empty-source guidance, and source manager entry.
- [x] Source manager opens and shows add/test/enable controls.
- [x] User-configured XML source can be tested, enabled, browsed, searched, filtered, and opened into detail/playback workflows.
- [x] Favorites and continue-watching flows work with source-backed content.
- [x] Desktop viewport has no obvious clipping or text overlap.
- [x] Mobile-sized viewport has no obvious clipping or text overlap.
- [x] Docs describe Web commands, Web workflow, and Web limitations.

## Evidence

- `npm test`: 2 test files, 5 tests passed.
- `npm run build`: TypeScript build and Vite production build passed.
- Local dev server: `npm run dev` served `http://127.0.0.1:5173/`.
- Browser desktop check: page title `Xvideo`, URL `http://127.0.0.1:5173/`, nonblank DOM with `Xvideo`, `配置源`, and empty-source guidance.
- Browser source manager check: dialog `视频源` opened and showed `添加资源`, `测试`, `测试并启用`, and `采集接口 URL`.
- Source-backed XML check: source test/enable, home browsing, keyword search, detail loading, playback source switching, favorites, continue-watching, category filtering, and mobile overflow checks passed.
- Playback note: one source-hosted iframe page returned a source-side 404, while an alternate direct video source played through the browser video path.
- Browser console check: no relevant `error` or `warn` logs during first-load and source-manager checks.
- Responsive check: 390 x 844 viewport had no horizontal overflow; source manager collapsed to one column and remained usable.
- Visual issue fixed during acceptance: main content initially painted above the source-manager modal because the modal was mounted inside the sidebar stacking context; the sidebar now has a higher stacking context so the modal covers the full app.

## Result

Accepted.
