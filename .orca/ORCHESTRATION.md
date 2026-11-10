# Orca Orchestration Operating Guide

This repository uses Orca's structured orchestration layer, not ad-hoc agent spawning.

## Core concepts

- **Run:** durable coordination namespace and Coordinator inbox.
- **Task:** a scoped unit of work with specification, dependencies, and status.
- **Dispatch:** one attempt to execute a Task on a Worker terminal.
- **Message:** status, question, escalation, heartbeat, or worker completion delivered through the Run.
- **Decision gate:** Coordinator-owned decision that blocks dependent work until resolved.

The Run does not itself schedule or place Workers. The Coordinator plans Tasks and explicitly dispatches them.

## Canonical lifecycle

Use the current official Orca guide and installed CLI help. The normal supervised path is:

```bash
orca status --json
orca orchestration run-create --objective "<objective>" --json
orca orchestration task-create --spec "<task spec>" --task-title "<short title>" --json
orca orchestration worker-start --task <task_id> --worktree current --agent <agent_id> --json
orca orchestration check --run <run_id>
```

Create every independent Task in a wave before dispatching the wave. Add dependencies only when there is a real ordering requirement. Do not create artificial chains.

`worker-start` is preferred for supervised work because it composes worktree, terminal, readiness, and dispatch operations. Use `dispatch --inject` only for a documented custom topology.

## Fresh-session rule

- Start a new Worker terminal for each dispatch.
- Do not pass a prior Worker transcript as context.
- Reuse only durable artifacts: task spec, project context, relevant source files, architecture/decision docs, and prior reports that directly affect the task.
- Prefer concise, explicit context lists over “read the whole repository”.
- If a task is retried, create a new dispatch attempt according to current Orca behavior; do not pretend a failed attempt succeeded.

## Worktree selection

- Use `--worktree current` when a Worker can safely work in the Coordinator's current checkout and there is no overlapping concurrent edit.
- Use `--worktree new-child --name <short-name>` when concurrent work needs filesystem isolation under the current workspace.
- Use `--worktree new-top-level --repo <exact-repo-selector> --name <short-name>` only when a separate top-level worktree is required.
- Do not assume Orca schedules tasks or infers file conflicts. The Coordinator decides concurrency and placement.
- Confirm exact option support with `orca orchestration worker-start --help` before relying on version-sensitive flags.

## Worker lifecycle

A dispatched Worker receives an Orca-generated lifecycle preamble. Follow it. In particular:
- Use Orca `ask` for blocking questions to the Coordinator; do not leave local interactive prompts waiting.
- Send exactly one `worker_done` outcome for the dispatch, including on failure, following the injected instructions.
- Include the Task and Dispatch IDs when required by the current protocol.
- Completion messages summarize work; they do not independently approve or merge it.

## Coordinator loop

1. Run `orca orchestration check --run <run_id>` when awakened or when checking for messages.
2. Process each message: answer questions, inspect completion reports, handle escalations, and update task state.
3. Verify the reported work in the repository and inspect diffs.
4. Dispatch the next ready task(s), resolve decision gates, or ask the user for a decision.
5. Update `.orca/state/STATE.md` and `.orca/state/CURRENT_TASK.md` with compact durable facts.
6. End the turn when waiting for dispatched Workers. Do not spin-poll indefinitely.

## QA and approval

For meaningful implementation:
1. Implementer reports completion.
2. Coordinator dispatches a fresh QA Reviewer with the acceptance criteria, diff/changed-file list, and relevant project context.
3. QA Reviewer independently inspects the implementation and runs relevant checks where feasible.
4. `APPROVED` means the reviewed scope meets the stated criteria; it does not imply deployment or human approval.
5. `REJECTED` returns a precise defect list to a fresh Implementer dispatch.
6. Limit retries. After repeated failures, stop and escalate with evidence rather than looping indefinitely.

## Recovery and safety

- Verify current Run, Task, and Dispatch records before restarting anything.
- Use `orca orchestration task-list --json` and `orca orchestration dispatch-show --task <task_id> --json` to inspect provenance.
- Never run global `orca orchestration reset` as routine cleanup. It can affect unrelated work.
- Do not claim a Worker was orchestrated unless the corresponding Task and Dispatch can be verified.
- If an operation fails, inspect its receipt and residual resources before retrying. Avoid duplicate dispatches.
- Do not perform destructive Git operations, push, release, deploy, or modify external services without explicit authorization.

## Official reference

The Orca CLI orchestration guide is version-sensitive. Consult:
- https://github.com/stablyai/orca/blob/main/docs/site/content/docs/cli/orchestration.mdx
- `orca skills get orchestration --full`
- `orca orchestration --help`
