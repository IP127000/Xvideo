# Xvideo Agent Guide

This root `AGENTS.md` is loaded by Codex for this repository. Follow it for every project change unless the user explicitly says to skip a step.

## Required Workflow

1. Inspect first.
   - Run `git status -sb`.
   - Check branch, remote, recent commits, and relevant files.
   - Preserve unrelated user changes.
2. Modify.
   - Keep edits scoped to the request.
   - Use existing SwiftUI/AppKit patterns.
   - Use `apply_patch` for manual edits.
3. Compile.
   - Run `swift build` after code changes.
   - Fix all compiler errors before continuing.
4. Test the project.
   - Run focused checks for the changed area.
   - For app/UI/player changes, run `Scripts/build_app.sh`, launch `.build/app/Xvideo.app`, and test the real macOS workflow.
5. Check `README.md`.
   - Update it for user-visible feature, UI, setup, source, screenshot, build, or usage changes.
   - If no README update is needed, say so in the final response.
6. Commit and push.
   - Stage only task-related files.
   - Commit locally with a clear message.
   - Push to GitHub after the commit succeeds.
7. Release when needed.
   - For code or app behavior changes, package and update the GitHub release.
   - Use date-only tags such as `2026-05-26`.
   - Preserve older date releases; replacing the same-day app asset is allowed.
8. Update release notes.
   - Keep notes bilingual and consistently ordered: `中文`, `English`, `Verification`, `Build`.
   - Include asset name and SHA-256.
   - Do not include concrete data source names, source URLs, or private testing details.
9. Final check.
   - Confirm working tree, push status, README status, and release formatting.

## Project Rules

- App name and UI brand: `Xvideo`.
- Built app path: `.build/app/Xvideo.app`.
- Build script: `Scripts/build_app.sh`.
- Release asset format: `Xvideo-YYYY-MM-DD-macOS.zip`.
- Package command:
  `ditto -c -k --sequesterRsrc --keepParent .build/app/Xvideo.app .build/releases/Xvideo-YYYY-MM-DD-macOS.zip`
- Never use destructive git commands or revert user changes unless explicitly requested.
