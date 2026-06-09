# Xvideo iOS Feature Intake Skill

Use this skill for new iOS features, iPhone UI behavior, playback behavior, source/search/browse behavior, persistence/download behavior, signing/install workflow changes, or user-visible bug fixes.

## Purpose

- Turn the request into a maintained iPhone product requirement before implementation.
- Keep `Docs/FeatureList.md` aligned with implemented and planned iOS behavior.
- Avoid letting historical desktop behavior define iOS requirements.

## Procedure

1. Compare the request with current code and `Docs/FeatureList.md`.
2. Write a short requirement analysis in working notes:
   - User problem on iPhone.
   - Existing behavior.
   - Required behavior change.
   - Constraints from `Docs/Architecture.md`, iOS signing, device testing, and private-source handling.
3. Update `Docs/FeatureList.md` only when durable product behavior changes.
   - Mark planned, in-progress, blocked, or implemented behavior honestly.
   - Remove stale entries only when the code or product decision actually changed.
   - Keep desktop-only behavior out of iOS acceptance requirements.
4. Create or update `Docs/Acceptance/<feature-slug>.md` when the behavior needs user-flow evidence.
   - Include requirement summary, scope, prerequisites, device/signing assumptions without private details, and a checklist mapped to `Docs/FeatureList.md`.
   - For tiny visible copy/layout changes, use a concise final-response note instead of a new acceptance document.

## Skip Rules

- Do not use this skill for workflow-only or non-behavioral documentation edits unless the documentation changes product behavior.
- Do not update feature or acceptance docs just because code was refactored internally.
- Do not record concrete private source names, source URLs, credentials, personal device details, or private test data.

## Output

Leave the requirement clear enough that implementation and acceptance can be checked against it. If no `Docs/FeatureList.md` or acceptance update was needed, record why in the final response.
