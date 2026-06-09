# Final Gate

Use this step before every final response unless the user explicitly asked for a status-only answer without new checks.

## Purpose

Leave the repository in a clear, explainable state and tell the user what was verified.

## Steps

1. Inspect final repository state.
   - Run `git status -sb`.
   - Confirm whether the branch is ahead, behind, diverged, or clean relative to upstream when upstream exists.
2. Summarize documentation status.
   - README updated, or not needed with a short reason.
   - Feature, architecture guidance, workflow, and acceptance docs updated where relevant.
3. Summarize verification status.
   - List commands run and outcomes.
   - Include `npm test` when logic, parsing, state, or persistence changed.
   - Include `npm run build` for code changes.
   - Include Web Acceptance for user-visible app changes.
   - State skipped checks and why.
4. Summarize release/GitHub status.
   - Release updated, package created, commit pushed, or PR opened when requested.
   - Otherwise state that publishing/release was not run because it was not requested.
5. Call out residual risk.
   - Mention blocked tests, unavailable Browser/Playwright, missing test data, private-source-dependent behavior, CORS/proxy limitations, media codec limitations, or browser download constraints.

## Done When

- The user can see what changed.
- The user can see what was verified.
- The user can see what remains uncommitted, unpushed, skipped, or blocked.
