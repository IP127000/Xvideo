# Feature Intake

Use this step for user-visible Web features, UI behavior changes, playback/source/search/download/persistence changes, and bug fixes that change what users can observe.

Skip this step for purely internal refactors, packaging-only work, and workflow/documentation edits that do not change product behavior.

## Purpose

Turn the request into a clear requirement before implementation, while keeping product documentation aligned without creating process noise for tiny changes.

## Steps

1. Compare the request with the current product surface.
   - Check `Docs/FeatureList.md`.
   - Inspect the owning components, hooks, services, tests, storage adapters, proxy code, or styles.
2. Write a short requirement analysis in the working notes.
   - User problem.
   - Current behavior.
   - Required behavior.
   - Relevant Web constraints, such as CORS/proxy behavior, localStorage, media playback, browser downloads, focus, keyboard shortcuts, responsive layout, and accessibility.
   - Architecture constraints from `AGENTS.md`.
3. Update `Docs/FeatureList.md` when product behavior changes.
   - Add new shipped behavior to the right feature area.
   - Adjust stale entries only when the code actually changes.
   - Mark planned or partial behavior only when the implementation is intentionally incomplete.
4. Create or update an acceptance document under `Docs/Acceptance/` when the change has meaningful user-facing risk.
   - Use a stable name such as `Docs/Acceptance/<feature-slug>.md`.
   - Include requirement summary, scope, prerequisites, test data assumptions without private source details, and a checklist tied to `Docs/FeatureList.md`.
   - For tiny copy/layout fixes, a concise final verification note is enough unless the user asks for a formal acceptance file.

## Done When

- The requirement is clear enough to implement.
- Product docs are updated when behavior changed.
- A formal acceptance checklist exists when the change needs real browser validation.
