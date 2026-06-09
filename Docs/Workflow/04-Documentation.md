# Documentation

Use this step whenever behavior, UI, setup, screenshots, source handling, build instructions, architecture, workflow, packaging, or release behavior changes.

## Purpose

Keep user-facing and contributor-facing documentation honest without turning every small code change into broad documentation churn.

## Steps

1. Check README impact.
   - Update `README.md` when user-visible behavior, setup, build, usage, source handling, screenshots, or release instructions change.
   - Keep `README.en.md` aligned when the same information exists there.
   - If no README update is needed, state the reason in the final response.
2. Keep product and architecture guidance aligned.
   - Update `Docs/FeatureList.md` when shipped product behavior changes.
   - Update the architecture reminders in `AGENTS.md` when layer boundaries, dependency direction, packaging shape, or development commands change.
3. Keep workflow docs aligned.
   - Update `AGENTS.md` when the default workflow, hard rules, platform scope, or workflow file index changes.
   - Update the relevant `Docs/Workflow/*.md` file when a step changes.
   - Avoid duplicating full workflow text in planning docs. Link back to `AGENTS.md` or `Docs/Workflow/` instead.
4. Keep acceptance docs factual.
   - Use `Docs/Acceptance/` for meaningful user-facing risk.
   - Avoid private source names, source URLs, credentials, and concrete private testing details.

## Done When

- README files are updated or explicitly not needed.
- Feature, architecture guidance, workflow, and acceptance docs match the final behavior.
- Documentation changes are scoped to the request.
