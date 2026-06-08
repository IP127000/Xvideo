# Xvideo iOS Documentation Skill

Use this skill when iOS behavior, UI, setup, signing, install, source handling, screenshots, build instructions, or usage changes.

## Purpose

- Keep user-facing and process documentation accurate without unrelated churn.
- Keep iOS behavior authoritative on the `ios` branch.
- Keep README, feature, and acceptance docs aligned only where they overlap.

## Procedure

1. Check `README.md` when public usage, setup, signing, source handling, screenshots, build, install, or behavior changes.
   - Update it only when the README contains information affected by the change.
   - If no README update is needed, say why in the final response.
2. Keep `README.en.md` aligned when the same user-visible information exists there.
3. Keep `Docs/FeatureList.md` aligned with final iOS behavior.
4. Keep acceptance docs factual and free of private details.
5. For process-only changes, update `AGENTS.md` and the relevant files under `Docs/WorkflowSkills/`.

## Skip Rules

- Do not update README for internal refactors, test-only changes, or workflow edits that do not affect public usage.
- Do not create acceptance docs for non-testable documentation cleanup.
- Do not copy historical desktop instructions into iOS requirements.

## Output

Report which docs changed, which docs were checked but not changed, and why any expected documentation was skipped.
