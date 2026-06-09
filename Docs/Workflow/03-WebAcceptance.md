# Web Acceptance

Use this step after user-visible changes to UI, playback, source management, search/browse, persistence, downloads, responsive behavior, or bug fixes that affect real app workflows.

Skip this step for docs-only changes and internal refactors that cannot plausibly affect visible behavior.

## Purpose

Validate the built Web app through the real browser workflow, not only by code inspection.

## Steps

1. Prepare the app.
   - Run `npm test` when logic, parsing, state, or service behavior changed.
   - Run `npm run build`.
   - Start `npm run dev` for interactive acceptance, or `npm run preview` when validating the production build.
2. Use the Browser plugin for functional confirmation when available.
   - Load the local app URL.
   - Verify page identity, nonblank content, absence of framework error overlays, console health, and screenshot evidence.
   - Click through the exact flow described in the acceptance document.
   - Verify visible UI states, navigation, persistence, playback/download state, error handling, responsive behavior, and recovery behavior as applicable.
3. Keep private data out of records.
   - Do not write concrete private source names, source URLs, credentials, or private test content into committed docs or release notes.
   - Use generic descriptions such as "a user-configured source" or "test media item".
4. Update the acceptance document when one exists.
   - Mark each checklist item as pass, fail, blocked, or not applicable.
   - Include concise evidence: build command, local URL, tested workflow, viewport, and observed result.
   - End with `Accepted`, `Rejected`, or `Blocked`.
5. If acceptance fails, fix and repeat.
   - Rebuild after the fix.
   - Repeat only the impacted acceptance path when appropriate.
6. If Browser is unavailable.
   - Use Playwright as fallback when practical.
   - Mark the Browser portion as blocked and record the fallback.
   - Do not claim full browser acceptance passed without rendered verification.

## Done When

- Web tests/build passed for the relevant change.
- The requested real workflow was accepted, rejected, or blocked with clear evidence.
- Any skipped acceptance work is explained.
