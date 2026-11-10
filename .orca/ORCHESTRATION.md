# Orca Orchestration Operating Guide

This repository uses Orca's structured orchestration layer, not ad-hoc agent spawning.
This file is the canonical source for the rules below. Other documents reference it
instead of restating them.

## Authority order

Orca's orchestration layer evolves with the CLI. Before relying on any command or flag:

1. `orca skills get orchestration` — the version-matched guide served by the installed
   binary. At an action gate, load only the reference you need:
   `orca skills get orchestration --reference references/<name>.md`
   (`--references` lists names; `--full` returns kernel + all references).
2. `orca orchestration <command> --help` — exact flags for the installed build.
3. `orca status --json` — runtime state and caller identity.
4. Official docs (`https://github.com/stablyai/orca/blob/main/docs/site/content/docs/cli/orchestration.mdx`)
   as background only; the binary-served guide is authoritative.

Never invent commands or flags. If the installed CLI rejects something documented here,
adapt to what it accepts and record the discrepancy.

## Resolve the executable first

Choose one executable and reuse it for the whole session:

1. `$ORCA_CLI_COMMAND` if set (Orca exports this for managed sessions).
2. Linux outside an Orca-managed terminal: `orca-ide`. Never bare `orca` there — it is
   normally the GNOME screen reader and starts speech on the user's machine.
3. Otherwise `orca` (Windows/macOS and inside Orca terminals).

Below, `orca` means the resolved executable.

## Core concepts

- **Run:** durable coordination namespace and Coordinator inbox. It never schedules or
  places workers.
- **Task:** a scoped unit of work with specification, dependencies, and status.
- **Dispatch:** one authoritative attempt to execute a Task on a Worker terminal.
- **Delivery:** the FIFO message batch `check` returns; acknowledged with `--ack`.
- **Decision gate:** a Coordinator-owned decision blocking a dependent Task
  (`gate-create --task <id> --question <text> [--options <json_array>]`,
  `gate-resolve --id <gate_id> --resolution <text>`, `gate-list`). See
  `references/messaging-and-gates.md`.

## Canonical lifecycle

```bash
orca status --json
orca orchestration run-create --objective "<objective>" --json
orca orchestration task-create --spec "<task spec>" --task-title "<short title>" --json
orca orchestration task-list --ready --brief --json
orca orchestration worker-start --task <task_id> --worktree current --agent <agent> --json
orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
```

Create every independent Task in a wave before dispatching the wave. Add `--deps` only
for real ordering; prefer parallel waves over chains deeper than three or four steps.
`--brief` caps echoed specs at 160 characters (`spec_truncated` flags shortened rows);
omit it when full specs matter.

In the Coordinator's own Orca terminal omit `--terminal` on `check`; pass `--run <run_id>`
only when the terminal is not bound to a Run. On Windows PowerShell quote comma-separated
lists: `--types "worker_done,escalation,question"`.

`worker-start` is the supervised path: it composes placement, terminal readiness, prompt
injection, dispatch, and owned-resource creation. `dispatch --inject` leaves an
operator-created process unsupervised; use it only for topologies `worker-start` cannot
express.

## Coordinator message loop

1. After dispatching a wave, **stay in the turn and wait**:
   `orca orchestration check --wait --types "worker_done,escalation,question" --timeout-ms <ms> --json`.
   Wake/nudge is best-effort attention; ending the turn does not guarantee Orca resumes
   the Coordinator, so waiting within the turn is the rule.
2. A returned Delivery is the whole FIFO batch and is never type-filtered. Process every
   message: answer questions (`orca orchestration reply --id <message_id> --body "<answer>" --json`),
   validate each `worker_done` against the expected active Dispatch, handle escalations.
3. After processing the entire batch, acknowledge it:
   `orca orchestration check --ack <delivery_id> --wait --types "worker_done,escalation,question" --timeout-ms <ms> --json`.
   An unacknowledged Delivery replays and hides newer mail. Repeat consume → process →
   ack until `deliveryId` is null.
4. Keep waiting until every expected Dispatch settles. A timeout or empty result is a
   checkpoint, not a failure.
5. After three consecutive empty waits, stop blind waiting and enumerate:
   `orca orchestration worker-list --run <run_id> --include-remote --json`.
   Act on each row's `projection.attention`, `projection.attention.requiresAction`, and
   literal `projection.nextAction`; page while `page.hasMore` with `--cursor`.
6. Before ending the turn, finish Settlement Accounting (below) and verify
   `orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json`
   returns none.

Never end the Coordinator turn with an unacknowledged Delivery or a reclaimable terminal.

## Settlement accounting

A valid `worker_done` settles the Task and Dispatch automatically. Do **not** follow it
with `task-update --status completed`.

After each accepted settlement, choose exactly one next owner for that worker terminal:

1. **Reuse** — the same agent has immediate follow-up work: recover the proven handle via
   `orca orchestration worker-show --dispatch <dispatch_id> --json`, then dispatch the next
   Task with `--terminal <handle>`. This is the only sanctioned exception to the
   fresh-session rule and must be recorded by the Coordinator.
2. **Retain** — `orca orchestration worker-retain --dispatch <dispatch_id> --json` only
   when the user explicitly asked to keep the settled terminal live.
3. **Release** — `orca orchestration worker-release --dispatch <dispatch_id> --json`.
   Release is post-settlement cleanup authorized **only by an accepted settlement**. It is
   not a cancellation tool: never release because of a timeout, idle TUI, heartbeat,
   unanswered question, or stale report. Follow `release_pending` / `release_unknown`
   receipts' recovery actions; never substitute a terminal close.

Release archives readable output, so `worker-read` still works afterwards. Verify reported
work with `orca orchestration worker-read --dispatch <dispatch_id> --source auto --json`
plus repository/diff inspection — not every worker has a terminal, and `worker-read` is
the supported read path either way.

## Fresh-session rule

- Launch every new Worker with `--agent <agent_id>`; never pass `--terminal` for fresh
  work. Terminal reuse is reserved for the documented follow-up exception above.
- Do not pass a prior Worker transcript as context. Durable context only: task spec,
  project context, enumerated files, decision docs, and prior reports that affect the task.
- Prefer concise, explicit context lists over "read the whole repository".
- On a retry, create a new Dispatch attempt (see Retry below); never pretend a failed
  attempt succeeded.

## Worktree placement

- `--worktree current` — Worker runs in the Coordinator's checkout; use only when no
  overlapping concurrent edit exists.
- `--worktree new-child --name <short-name>` — isolated child worktree under the current
  workspace; required when concurrent edits could conflict.
- `--worktree new-top-level --repo <selector> --name <short-name>` — separate top-level
  worktree when one is genuinely required.
- Creation flags (`--name`, `--repo`, `--base-branch`) are rejected on current/existing
  worktrees. Remote placement rejects `current`/`new-child`; discover an exact selector or
  use `new-top-level`.
- Orca does not schedule Tasks or infer file conflicts. The Coordinator decides
  concurrency and placement. Confirm version-sensitive flags with
  `orca orchestration worker-start --help`.

## Parallel waves and ownership

Before dispatching a concurrent wave, compare each ready Task's `OWNERSHIP` paths
(`protocols/TASK_PROTOCOL.md`) against the allowed paths of all active Dispatches. On any
overlap: serialize the Tasks, merge them into one Task, or give each an isolated worktree.
Use `task-list --ready --brief --json` as the durable task-graph view.

## Worker lifecycle (worker_done contract)

A dispatched Worker receives an Orca-generated lifecycle preamble; the preamble is
authoritative. Invariants:

- Use Orca `ask` for blocking questions to the Coordinator; never leave a local
  interactive prompt waiting. Send heartbeats only at the preamble's cadence.
- Send exactly one `worker_done` for the dispatch, from the dispatched terminal, with
  `--outcome succeeded` or `--outcome failed` — no other value exists.
- Always include `--task-id <task_id> --dispatch-id <dispatch_id>`; add
  `--files-modified <csv>` and `--report-path <path>` only with real values.
- The lifecycle outcome describes whether the **dispatch completed its work**. Review
  verdicts (`APPROVED` / `REJECTED` / `NEEDS_DECISION`) and blocked state live in the
  report, not in the outcome: a completed `REJECTED` review is `--outcome succeeded`.
  A Worker that cannot finish its task uses `ask`/escalation while running and sends
  `--outcome failed` only when the dispatch truly cannot complete.
- Completion messages summarize work; they never approve or merge it.

## Retry and rework (duplicate and infinite-retry prevention)

- **Execution failure** (`worker_done --outcome failed` or a proven stop): create a new
  attempt on the same Task:
  `orca orchestration worker-start --task <failed_task_id> --retry-of <dispatch_id> --worktree <placement> --agent <agent> --json`
  `--retry-of` requires `--task` naming the failed Task (`--spec` would silently create a
  new Task) and does **not** inherit placement: repeat the intended worktree and agent.
- **QA `REJECTED`**: create a fix Task referencing the QA report path, dispatch a fresh
  Implementer on it, then a fresh QA Task/Dispatch. A completed (succeeded) dispatch is
  never `--retry-of`-ed.
- Create a new Task only when the scope genuinely changed; do not orphan the old Task to
  dodge a failure.
- Orca circuit-breaks a Task after three failed `worker-start` attempts (counted across
  `--retry-of`); further retry is refused with `task_not_startable`. At that point stop
  retrying and escalate to the user with evidence. Do not route around the breaker with a
  new Run, Task, or unrelated Dispatch. A Worker's own `failed` report does not count
  toward the breaker; failed starts do.
- `worker-start` exits 0 only for `ready`. On a non-zero exit read the receipt's
  `failedStage`, `residualResources`, and recovery commands; never relaunch blindly while
  residual resources are unaccounted for. A start that failed after creating a terminal
  still owns it: release it per its receipt (`worker-list` reports the row as
  `reclaimable`).

## Run resume

Run binding lives in the calling terminal; a restarted Coordinator starts unbound.

1. Read the local binding `.orca/local/run.md` (gitignored). If it names a Run ID:
   `orca orchestration run-use --id <run_id>` and verify with `run-current --json`.
2. If no local binding exists, list this machine's Runs with `run-list --json`, match by
   objective, and `run-use` it. If none matches, `run-create`.
3. Record a new Run ID **only** in `.orca/local/run.md`. Never commit runtime IDs to
   shared state files: they reference this machine's Orca runtime and are meaningless on
   another machine.
4. While unbound, always pass `--run <run_id>` explicitly. Unscoped `worker-list`
   enumerates every Dispatch this runtime has ever recorded and buries the live ones;
   Run-scoped defaults read nothing.

## Stuck / failed worker recovery

Do not treat silence as death. Stop, abandon, retry, or release only on **positive proof
the agent stopped**: an `exited` liveness verdict from `worker-list`, your own observation
of process exit, or a `worker-read` transcript whose final agent turn sent no
`worker_done`. `unverifiable` is absence — keep waiting or inspecting; absence never
authorizes action.

- `worker-show --dispatch <id> --json` reports PTY liveness and `observation.agentWait`;
  a worker parked on a human prompt is healthy, not failed. `worker-list`'s
  `projection.liveness` is the fleet verdict for the agent.
- `outcome_unknown`: inspect, then choose explicitly —
  `orca orchestration worker-stop --dispatch <dispatch_id> --json` (fences and closes only
  the proven owned terminal; receipt `processAction` says what happened; `stop_unknown`
  exits 1 — inspect `worker-show` before acting further) or
  `orca orchestration worker-abandon --dispatch <dispatch_id> --json` (fences orchestration
  while keeping possibly-live resources; performs no process/filesystem action).
- Cancel a Task: settle its worker first, then
  `orca orchestration task-update --id <task_id> --status failed --result cancelled --json`.
  Dependents stay blocked until a `--retry-of` replacement completes it.
- Lost mutation response: `orca orchestration request-show --request <request_id> --json`
  (read-only). `completed` → read the recorded receipt; `pending` → replay the original
  command with `--retry-request <request_id>`; `absent` is not proof nothing happened —
  inspect Task/Dispatch/terminal before retrying. Every orchestration mutation accepts
  `--retry-request <id>` so Orca replays instead of starting a duplicate.
- Unrecoverable state: escalate to the user with Task/Dispatch IDs, receipts, and residual
  resources. Do not loop.

For details load `orca skills get orchestration --reference references/recovery-and-cleanup.md`.

## QA and approval

For meaningful implementation:

1. Implementer dispatch completes (`worker_done --outcome succeeded`) with a report.
2. Coordinator dispatches a fresh QA Reviewer with the acceptance criteria, changed-file
   list / diff location, and report path.
3. QA independently inspects the implementation and runs relevant checks.
4. `APPROVED` means the reviewed scope meets the stated criteria; it does not imply
   deployment, push, or human approval.
5. `REJECTED` / `NEEDS_DECISION` are review verdicts recorded in the report while the QA
   dispatch still settles `succeeded`; the Coordinator routes the fix per Retry and rework
   above.
6. Retry limits are enforced by the dispatch circuit breaker plus Coordinator judgment;
   after repeated failures, stop and escalate with evidence.

## Recovery and safety

- Verify current Run/Task/Dispatch records (`task-list --json`,
  `dispatch-show --task <task_id> --json`, `worker-list --run <run_id> --json`) before
  restarting anything.
- `orca orchestration reset` is destructive recovery (`--all | --tasks | --messages`
  scope). Never routine cleanup; never during active coordination unless the user
  explicitly abandons that state.
- Do not claim a Worker was orchestrated unless the corresponding Task and Dispatch can
  be verified.
- No destructive Git operations, push, release, deploy, or external-service changes without
  explicit authorization.
