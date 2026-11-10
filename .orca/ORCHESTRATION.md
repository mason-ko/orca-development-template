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
   literal `projection.nextAction`; page while `page.hasMore` with `--cursor`. Classify
   every row against §Worker recovery: state model before acting; `UNVERIFIABLE` never
   authorizes stop/abandon/retry/release and never a re-dispatch — escalate instead.
6. Before ending the turn, finish terminal cleanup on both paths (§Dispatch settlement
   and terminal cleanup) and verify
   `orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json`
   returns none.

Never end the Coordinator turn with an unacknowledged Delivery or a reclaimable terminal.

## Dispatch settlement and terminal cleanup

Two cleanup paths with different triggers. **A failed `worker-start` is never an accepted
settlement**; do not apply Path A rules to it, and do not apply Path B reasoning to a
completed Worker.

### Path A — normal Worker completion (`worker_done` received)

1. The Worker runs and sends exactly one `worker_done` (`--outcome succeeded|failed`).
2. The accepted `worker_done` settles the Task and Dispatch automatically. Do **not**
   follow it with `task-update --status completed`.
3. Choose exactly one next owner for that worker terminal:
   - **Reuse** — the same agent has immediate follow-up work: recover the proven handle
     via `orca orchestration worker-show --dispatch <dispatch_id> --json`, then dispatch
     the next Task with `--terminal <handle>`. This is the only sanctioned exception to
     the fresh-session rule and must be recorded by the Coordinator.
   - **Retain** — `orca orchestration worker-retain --dispatch <dispatch_id> --json` only
     when the user explicitly asked to keep the settled terminal live.
   - **Release** — `orca orchestration worker-release --dispatch <dispatch_id> --json`,
     authorized on Path A by the accepted settlement. It is not a cancellation tool:
     never release to stop a running Worker, and never release because of a timeout,
     idle TUI, heartbeat gap, unanswered question, or unverifiable status.
4. Follow `release_pending` / `release_unknown` receipts' recovery actions; never
   substitute a terminal close. Release archives readable output, so `worker-read` still
   works afterwards.

### Path B — Worker start failed (no `worker_done` exists)

`worker-start` exits 0 only for `ready`; a non-zero exit is a start failure, not a
settlement. Never treat it as one, and never relaunch blindly.

1. Read the failure receipt: `failedStage`, `residualResources`, and the recovery
   commands it names.
2. Enumerate residuals: `orca orchestration worker-list --run <run_id> --json` (and
   `worker-show` where the receipt names a Dispatch). A start that created a terminal
   before failing still owns it: `worker-list` reports that row as `reclaimable` and the
   receipt names `worker-release` for that exact terminal. Release it through that
   receipt-driven cleanup — this is Path B residual cleanup, not Path A settlement — and
   never close terminals by hand.
3. Verify Task and Dispatch state (`task-list --json`,
   `dispatch-show --task <task_id> --json`) and confirm no live duplicate of the attempt
   exists.
4. Retry only per §Retry and rework (`--retry-of` on a positively proven failed attempt;
   a `--retry-of` replacement releases the failed Worker's still-owned terminal the same
   receipt-driven way). If the receipt names no safe cleanup action or residue is
   unaccounted for, **escalate to the user** instead of restarting.

### Verification and turn-end gate (both paths)

Verify reported work (Path A) with `orca orchestration worker-read --dispatch <dispatch_id>
--source auto --json` plus repository/diff inspection — not every Worker has a terminal,
and `worker-read` is the supported read path either way. Before ending the Coordinator
turn, `orca orchestration worker-list --run <run_id> --terminal-state reclaimable --json`
must return none; Path B residuals count toward this gate too.

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
- `worker-start` exits 0 only for `ready`. A non-zero exit is a **start failure, not an
  accepted settlement**: handle it as Path B in §Dispatch settlement and terminal cleanup
  (read `failedStage`/`residualResources`/recovery commands, enumerate residuals, clean
  up only via the receipt-named action). Never relaunch blindly while residual resources
  are unaccounted for; if no safe cleanup action is confirmed, escalate instead of
  restarting.

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

## Worker recovery: state model

Classify the Worker's state from evidence before acting. **A stop request is not process
termination, and silence is not death.** While any attempt of a Task is in a state other
than TERMINATED or settled, never re-dispatch that Task — a duplicate live Worker is the
failure this model exists to prevent.

| State | Evidence | Permitted actions |
|---|---|---|
| **RUNNING** | `worker-list` fleet verdict `live`; progress advancing (heartbeat/turn activity; `worker-read` tail moves between reads) | Keep waiting; optionally bounded `worker-read` |
| **UNRESPONSIVE** | fleet verdict `live` but no progress past a checkpoint; `worker-show --dispatch <id> --json` shows `observation.agentWait` (parked on a human prompt — **healthy, not failed**) or a stalled transcript tail | Inspect first; answer the prompt or escalate the question. Orca's canonical loop prefers waiting over stopping a live Worker: use `worker-stop` here only as an explicit, recorded recovery/cancellation decision (with user approval when the cancellation is risky). The stop fences the Dispatch; it does not prove the process exited |
| **STOP_REQUESTED** | `worker-stop` receipt returned with `processAction: none|unknown` or `stop_unknown` (exit 1) — close requested/attempted, exit unproven | Re-verify with `worker-show` and `worker-list`. `processAction: closed_agent_terminal` means Orca issued the close (do not also run terminal close) but the exit verdict still must be read back. While still unproven, treat as UNVERIFIABLE, not TERMINATED |
| **TERMINATED** | positive process-exit proof: an `exited` fleet verdict, observed process exit, or a `worker-read` transcript that positively shows the agent's final turn ended without sending `worker_done` — only after checking `contentComplete`, `clipping`, and `warnings`, and corroborated by `worker-list`/`worker-show` | Inspect residual resources (`worker-list --run <run_id> --json`, receipts) and Task/Dispatch state (`task-list`, `dispatch-show`), then clean up per receipts (§Dispatch settlement and terminal cleanup Path B) or retry per §Retry and rework |
| **UNVERIFIABLE** | `missing_status`, `host_unavailable`, `capability_unsupported`, remote contact loss, or an uncorroborated transcript signal — absence of trustworthy status, not evidence of death | **Never** stop, abandon, retry, release, or re-dispatch. Keep waiting where possible; otherwise escalate to the user with IDs and receipts. Do not loop |

Rules:

- Liveness layering: `worker-list`'s `projection.liveness` is the fleet verdict for the
  agent; `worker-show`'s `observation.status` is PTY liveness only (a live terminal can
  still hold a dead or stuck agent). When they disagree, the fleet verdict decides —
  unless the fleet row is `unverifiable` for a client-side gap (`missing_status`,
  `host_unavailable`, `capability_unsupported`), where a `worker-show` verdict sourced
  from the execution host is the better evidence. Either command's `unverifiable`
  authorizes nothing.
- `worker_done` absent from a bounded `worker-read` result proves nothing by itself:
  output may be clipped, still running, or read from the wrong source. Absence is
  absence; it only feeds the classification above.
- `worker-stop --dispatch <dispatch_id> --json` fences one Dispatch and stops its
  supervised agent terminal. It never deletes the worktree, setup terminals, or unrelated
  processes. Its exit code and `processAction` describe the *request*, not the outcome;
  STOP_REQUESTED must be re-checked before any next action.
- `worker-abandon --dispatch <dispatch_id> --json` fences orchestration **without
  claiming the process stopped**: it performs no process or filesystem action and retains
  all possibly-live resources. Per the installed recovery reference, when it settles a
  Worker it retains the owned terminal like `worker-retain`, so Orca stops owing its
  release. Use it when fencing must be recorded but a stop cannot be proven or is
  unwanted; record the possibly-live resources explicitly.
- Cancel a Task: settle its Dispatch first via `worker-stop` or `worker-abandon` (per the
  state above), then `orca orchestration task-update --id <task_id> --status failed
  --result cancelled --json`. Dependents stay blocked until a `--retry-of` replacement
  completes it.
- An `outcome_unknown` attempt (receipt-level: start outcome not established): inspect,
  then choose explicitly between `worker-stop` and `worker-abandon` per the receipt's
  recovery commands; do not retry while its outcome is unknown.
- Lost mutation response: `orca orchestration request-show --request <request_id> --json`
  (read-only). `completed` → read the recorded receipt; `pending` → replay the original
  command with `--retry-request <request_id>`; `absent` is not proof nothing happened —
  inspect Task/Dispatch/terminal before retrying. Every orchestration mutation accepts
  `--retry-request <id>` so Orca replays instead of starting a duplicate.
- Unrecoverable state: escalate to the user with Task/Dispatch IDs, receipts, and
  residual resources. Do not loop.

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
