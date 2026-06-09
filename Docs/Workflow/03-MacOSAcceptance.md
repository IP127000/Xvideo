# macOS Acceptance

Use this step after user-visible changes to UI, playback, source management, search/browse, persistence, downloads, window behavior, or bug fixes that affect real app workflows.

Skip this step for docs-only changes and internal refactors that cannot plausibly affect visible behavior.

## Purpose

Validate the built macOS app through the real desktop workflow, not only by code inspection.

## Steps

1. Prepare the app.
   - Run `Scripts/build_app.sh`.
   - Launch `.build/app/Xvideo.app`.
2. Use Computer Use for functional confirmation when available.
   - Click through the exact flow described in the acceptance document.
   - Verify visible UI states, navigation, persistence, playback/download state, error handling, and recovery behavior as applicable.
   - Include macOS-specific checks such as window sizing, focus, keyboard shortcuts, player surface behavior, Finder handoff, and modal/sheet behavior when relevant.
3. Keep private data out of records.
   - Do not write concrete private source names, source URLs, credentials, or private test content into committed docs or release notes.
   - Use generic descriptions such as "a user-configured source" or "test media item".
4. Update the acceptance document when one exists.
   - Mark each checklist item as pass, fail, blocked, or not applicable.
   - Include concise evidence: build command, app launch path, tested workflow, and observed result.
   - End with `Accepted`, `Rejected`, or `Blocked`.
5. If acceptance fails, fix and repeat.
   - Rebuild after the fix.
   - Repeat only the impacted acceptance path when appropriate.
6. If Computer Use is unavailable.
   - Run all non-interactive checks that still apply.
   - Mark the computer-use portion as blocked.
   - Do not claim full UI acceptance passed.

## Done When

- The macOS app build passed.
- The requested real workflow was accepted, rejected, or blocked with clear evidence.
- Any skipped acceptance work is explained.
