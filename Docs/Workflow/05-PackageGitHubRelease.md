# Package, GitHub, and Release

Use this step only when the user explicitly asks to ship, publish, push, create a PR, package the app, or update a GitHub Release.

Do not run this step as a side effect of ordinary implementation work.

## Purpose

Ship a verified macOS app package and keep GitHub state consistent when release or publishing work is requested.

## Prerequisites

- Code changes have passed `swift build`.
- User-visible app changes have passed `Scripts/build_app.sh` and macOS Acceptance, or any blocked acceptance is clearly documented.
- `Docs/Acceptance/` has a final conclusion when formal acceptance was required.
- README, feature, architecture, and workflow docs are aligned where relevant.

## Steps

1. Review the change set.
   - Run `git status -sb`.
   - Inspect the diff.
   - Stage only task-related files.
2. Commit when requested.
   - Use a clear commit type:
     - `feat:` user-visible functionality.
     - `fix:` bug fixes.
     - `refactor:` internal structure changes without behavior changes.
     - `docs:` documentation-only changes.
     - `chore:` tooling, scripts, repository setup.
   - Prefer small, clear commits.
3. Push or create a PR when requested.
   - Confirm the branch and remote before pushing.
   - Do not push unrelated local work.
4. Package the app when requested.
   - Run `Scripts/build_app.sh` first.
   - Use date-only release tags such as `2026-06-08`.
   - Build asset name: `Xvideo-YYYY-MM-DD-macOS.zip`.
   - Package command:

     ```bash
     ditto -c -k --sequesterRsrc --keepParent .build/app/Xvideo.app .build/releases/Xvideo-YYYY-MM-DD-macOS.zip
     ```

5. Compute the asset SHA-256.
6. Create or update the GitHub Release when requested.
   - Preserve older date releases and assets unless intentionally replacing the same-day app asset.
   - Keep release notes bilingual and consistently ordered:
     1. `中文`
     2. `English`
     3. `Verification`
     4. `Build`
   - Include asset name and SHA-256.
   - Do not include concrete data source names, source URLs, credentials, or private testing details.

## Done When

- Requested GitHub actions are complete.
- Requested app package and release assets are created or updated.
- Asset name, SHA-256, verification, and build details are recorded.
