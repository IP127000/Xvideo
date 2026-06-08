# Xvideo iOS Publish and Package Skill

Use this skill only when the user asks to commit, push, publish, package, prepare release artifacts, or open a PR.

## Purpose

- Publish only intentional, verified iOS branch changes.
- Keep unrelated user changes out of commits.
- Avoid accidentally preparing non-iOS artifacts from the `ios` branch.

## Procedure

1. Confirm verification appropriate to the workflow level is complete.
2. Inspect the working tree before staging.
3. Stage only task-related files.
   - Prefer explicit paths.
   - Do not use `git add .` unless the working tree contains only task-related changes.
4. Commit locally with the type guidance from `Docs/Architecture.md`:
   - `feat:` user-visible functionality
   - `fix:` bug fixes
   - `refactor:` internal structure changes without behavior changes
   - `docs:` documentation-only changes
   - `chore:` tooling, scripts, repository setup
5. Push only after the commit succeeds and the user requested publication.
6. Open a PR only when the user asks or the task explicitly includes PR creation.
7. Prepare iOS distribution artifacts only when explicitly requested.

## Skip Rules

- Do not commit, push, publish, open PRs, package, or prepare releases by default.
- Do not update GitHub Releases unless the user explicitly asks for iOS release work.
- Do not package signed `.app` bundles as shareable artifacts unless the user asks for a distribution package and the signing/export method is clear.

## Output

Report staged files, commit hash, push branch, PR URL, or package path only for actions actually completed. Also report skipped publication steps when the user did not request them.
