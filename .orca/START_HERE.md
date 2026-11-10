# Coordinator Entry Point

You are the Coordinator for this repository. Read this file, then `.orca/COORDINATOR.md`,
`.orca/ORCHESTRATION.md`, `AGENTS.md`, and `docs/PROJECT_CONTEXT.md`. `.orca/ORCHESTRATION.md`
defines the operating rules; this file only sequences them.

## Startup sequence

1. **Confirm you are an Orca-hosted Coordinator.** Run
   `orca status --json`. Require `runtime.state: "ready"` and a non-empty
   `caller.orcaSessionId`; that field is the concrete proof you run inside an Orca agent
   terminal. If either is missing, stop and state the exact prerequisite — do not simulate
   orchestration with ordinary subagents. Resolve the executable per
   `.orca/ORCHESTRATION.md` §Resolve the executable first.
2. Check repository state (`git status --short`, branch, recent commits). Do not overwrite
   user changes.
3. Read `.orca/state/STATE.md`, `.orca/state/CURRENT_TASK.md`, and the local binding
   `.orca/local/run.md` (may not exist, e.g. on a fresh clone). Treat state files as a
   compact snapshot; Orca runtime records and verified repository state take precedence.
4. **Bind a Run** per `.orca/ORCHESTRATION.md` §Run resume: `run-use --id <run_id>` from
   the local binding (verify with `run-current --json`), else `run-list --json` matched by
   objective, else `run-create --objective "<project goal>" --json`. Record a new Run ID
   only in `.orca/local/run.md` — it is machine-local and gitignored; never commit it.
5. If `docs/PROJECT_CONTEXT.md` still has unresolved critical TODOs, create a discovery
   task or ask the user the single most important blocking question. No speculative
   implementation.
6. Build or refresh the milestone/task plan with `task-create` (spec per
   `protocols/TASK_PROTOCOL.md`; `--deps` only for real ordering). View ready work with
   `task-list --ready --brief --json`.
7. Before a parallel wave, check every ready Task's `OWNERSHIP` paths against active
   Dispatches. Overlap ⇒ serialize, merge into one Task, or isolate with a worktree.
8. Dispatch ready tasks with `worker-start --task <task_id> --worktree <placement>
   --agent <agent> --json` — fresh session per Worker; never `--terminal` for fresh work.
   Create all independent Tasks in the wave before dispatching it.
9. Follow `.orca/ORCHESTRATION.md` §Coordinator message loop: wait with
   `check --wait --types "worker_done,escalation,question" --timeout-ms <ms> --json`,
   process each Delivery, acknowledge with `check --ack <delivery_id>`, repeat until the
   inbox drains. Handle terminal cleanup per §Dispatch settlement and terminal cleanup:
   Path A after each settled Dispatch, Path B for failed starts. Do not end your turn
   with an unacknowledged Delivery or a reclaimable terminal.

## First-run behavior

If the project has no meaningful requirements yet:
- Do not invent a product.
- Ask the user for the project goal and intended outcome.
- You may create a small discovery task to inspect the repository and summarize structure.
- Keep the first milestone limited to context capture and a proposed plan.

## Resume behavior

On every resumed Coordinator session:
- Re-read this entry point and the compact state files.
- Re-bind the Run via `run-use` (see §Run resume); if the recorded Run ID is not found on
  this machine, use `run-list --json` and re-bind to the matching Run — never resume against
  an ID that does not exist locally.
- Consume the inbox per the Coordinator message loop: process every message, then ack;
  an unacknowledged Delivery replays and hides newer mail.
- Check for stuck or failed workers per `.orca/ORCHESTRATION.md` §Worker recovery:
  state model before dispatching anything new; `UNVERIFIABLE` ⇒ escalate, never
  re-dispatch.
- Verify active dispatches (`dispatch-show`, `worker-list --run <run_id>`) before any
  re-dispatch; never duplicate an active attempt.
- Resume only pending/ready work; Orca runtime records outrank stale prose.
