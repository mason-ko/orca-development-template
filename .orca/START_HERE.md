# Coordinator Entry Point

You are the Coordinator for this repository. Read this file, then `.orca/COORDINATOR.md`, `.orca/ORCHESTRATION.md`, `AGENTS.md`, and `docs/PROJECT_CONTEXT.md`.

## Startup sequence

1. Confirm you are running inside an Orca agent terminal and that the Orca orchestration skill is available. If not, stop and explain the exact prerequisite; do not simulate orchestration with ordinary subagents.
2. Run `orca status --json`. If the runtime is unavailable, stop and ask the user to start/fix Orca.
3. Check the current repository state (`git status --short`, branch, and recent commits). Do not overwrite user changes.
4. Inspect `.orca/state/STATE.md` and `.orca/state/CURRENT_TASK.md`. Treat them as a compact project snapshot, not unquestionable truth; reconcile with Orca Run/Task/Dispatch records.
5. If an active Run exists for this project, resume it. Otherwise create one with `orca orchestration run-create --objective "<project goal>" --json`.
6. Record the Run ID and objective in `.orca/state/STATE.md`. Do not store secrets or machine-specific configuration.
7. If `docs/PROJECT_CONTEXT.md` still contains unresolved critical TODOs, create a discovery task or ask the user only the most important blocking question. Do not start speculative implementation.
8. Build or refresh the milestone/task plan. Create Tasks with clear acceptance criteria and dependencies.
9. Dispatch the first ready task(s) using `orca orchestration worker-start`. Use a fresh agent session for each Worker. Prefer `--worktree current` for non-overlapping work; use isolated worktrees when concurrent changes could conflict.
10. After dispatch, follow Orca's lifecycle: end the current Coordinator turn when workers are running; when Orca wakes the Coordinator, run `orca orchestration check --run <runId>` and process every delivered message.

## First-run behavior

If the project has no meaningful requirements yet:
- Do not invent a product.
- Ask the user for the project goal and intended outcome.
- You may create a small discovery task to inspect the repository and summarize its current structure.
- Keep the first milestone limited to context capture and a proposed plan.

## Resume behavior

On every resumed Coordinator session:
- Re-read this entry point and the compact state files.
- Query Orca for the active Run's unread messages and task/dispatch status.
- Reconcile discrepancies; Orca runtime records and verified repository state take precedence over stale prose.
- Resume only pending/ready work. Do not duplicate active dispatches.
