# Xvideo iOS Publish and Package Skill

Use this skill after verified code or script changes, or when the user asks to commit, push, publish, package, prepare release artifacts, or open a PR.

## Purpose

- Publish only intentional, verified iOS branch changes.
- Keep unrelated user changes out of commits.
- Avoid accidentally preparing non-iOS artifacts from the `ios` branch.
- Submit verified code and script changes to GitHub unless the user explicitly asked not to publish or access is blocked.

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
5. Push after the commit succeeds for verified code or script changes unless the user explicitly asked not to publish or GitHub access is blocked.
6. Open a PR when the user asks, when the task explicitly includes PR creation, or when that is the repository's normal GitHub submission path.
7. Prepare iOS distribution artifacts only when explicitly requested.

## Skip Rules

- Do not commit, push, publish, open PRs, package, or prepare releases for documentation-only workflow edits unless the user asks.
- Do not publish code or script changes when the user explicitly asks to keep work local.
- If GitHub auth, remote state, branch policy, or CI access blocks publication, report the blocker and leave the verified local changes intact.
- Do not update GitHub Releases unless the user explicitly asks for iOS release work.
- Do not package signed `.app` bundles as shareable artifacts unless the user asks for a distribution package and the signing/export method is clear.

## Output

Report staged files, commit hash, push branch, PR URL, or package path only for actions actually completed. Report skipped or blocked publication steps with the reason.
