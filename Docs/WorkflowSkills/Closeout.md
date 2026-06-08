# Xvideo iOS Closeout Skill

Use this skill before final responses after project changes, scaled to the work performed.

## Purpose

- Leave the repository state and verification status clear.
- Make skipped checks explicit without pretending they passed.
- Avoid turning every small doc or workflow task into a full build, install, acceptance, and release checklist.

## Procedure

1. Run `git status -sb` when files were changed or when current status is not already known.
2. Report ahead/behind state when visible.
3. Report documentation status when relevant:
   - Updated.
   - Checked and not needed, with a short reason.
   - Skipped because the user requested a narrower scope.
4. Report verification status:
   - Commands run and outcomes.
   - Checks skipped and why.
   - Physical iPhone UI items that remain blocked or pending.
5. Report publish/package status only when relevant:
   - Not performed because the user did not ask.
   - Completed iOS publication steps when requested.

## Skip Rules

- If the user explicitly asks not to run workflow steps, do not run build, install, launch, acceptance, publishing, or release gates.
- For workflow-audit-only tasks, report the docs changed and the workflow gates intentionally skipped.
- Do not mention non-iOS release status unless the task touched release documentation or the user asked about it.

## Output

Give a concise final summary: changed files, verification performed or skipped, repository status, and any residual risk.
