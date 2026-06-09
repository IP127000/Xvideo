# Start Here

Use this step before editing, reviewing, packaging, or releasing unless the user explicitly asks to skip workflow checks.

## Purpose

Understand the repository state, classify the request, and protect unrelated work before making changes.

## Steps

1. Inspect repository state.
   - Run `git status -sb`.
   - Confirm the current branch, upstream state, remote, and recent commits when the task involves changes that may be committed, pushed, or released.
   - Note untracked or modified files that are not part of the task.
2. Classify the request.
   - User-visible feature or bug fix.
   - Internal refactor.
   - Documentation-only change.
   - Packaging, GitHub, or release task.
   - Workflow/process change.
3. Read the relevant context.
   - Read `Docs/FeatureList.md` for product behavior changes.
   - Read the architecture reminders in `AGENTS.md` before structure, data flow, packaging, or release changes.
   - Read nearby SwiftUI, AppKit, Domain, Data, Infrastructure, or App files before planning code edits.
   - For workflow/process changes, read `AGENTS.md` and the relevant `Docs/Workflow/*.md` files first.
4. Protect user work.
   - Do not revert unrelated edits.
   - Do not stage unrelated files.
   - Ask only when unrelated changes make the requested work unsafe or impossible.

## Done When

- The request lane is known.
- Relevant docs and files have been read.
- Unrelated local changes are identified and left alone.
- The next workflow step is clear.
