# Orca Development Template — v1.0.1

A technology-agnostic GitHub template for running software projects through **Orca
Orchestration**.

> Orca is an external prerequisite. This repository contains project instructions,
> operating protocols, starter state, and bootstrap scripts. It does not vendor Orca or
> prescribe a language, framework, database, build system, or deployment platform.

**v1.0.1** corrects the orchestration protocol against the installed Orca CLI
(version-matched guide): Coordinator wait/ack loop, worker terminal settlement, safe
Linux bootstrap executable resolution, lifecycle-outcome vs report-verdict separation,
retry/circuit-breaker rules, Run resume, and machine-local Run bindings. See `.orca/
ORCHESTRATION.md` for the canonical rules.

## Principles

- One Coordinator owns the project plan, task graph, decisions, dispatch settlement, and
  recovery.
- Each dispatched Worker runs in a fresh agent session launched via `worker-start
  --agent`; previous Worker conversation history is never passed on.
- Pass only task-relevant context (spec, files, report paths) to each Worker.
- Persist durable knowledge in repository files and Orca Run/Task/Dispatch records.
- Machine-local runtime data (Run IDs, terminal handles) lives in gitignored
  `.orca/local/`, never in shared state files.
- Use independent QA review for meaningful implementation work; QA verdicts are report
  content, distinct from lifecycle outcomes.
- Keep this template technology-neutral. Project-specific tooling belongs in
  `docs/PROJECT_CONTEXT.md`.

## Prerequisites

1. Install and configure Orca separately.
2. Enable **Orchestration** in Orca Settings → Experimental if required by your installed
   version.
3. Ensure `orca status --json` succeeds from inside an Orca agent terminal (the
   Coordinator session must expose `caller.orcaSessionId`).
4. Ensure the version-matched orchestration guide is available:
   `orca skills get orchestration`. Treat this guide and the installed CLI `--help` as
   authoritative over anything written here.
5. Open this repository as a project/workspace in Orca and start a Coordinator agent in
   that workspace.

### Executable resolution

Before running any Orca command, pick one executable and reuse it:

1. `$ORCA_CLI_COMMAND` if set (Orca exports it for managed sessions).
2. On Linux outside an Orca terminal: `orca-ide`. **Never** bare `orca` — it is normally
   the GNOME screen reader.
3. Otherwise: `orca`.

## Quick start

### Windows PowerShell

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\bootstrap.ps1
```

### macOS / Linux

```bash
bash scripts/bootstrap.sh
```

The bootstrap scripts **verify** prerequisites: they resolve a safe Orca executable (see
above), run `orca status --json`, and confirm the starter-state files exist. They do not
create files, launch agents, or dispatch work; existing repositories pass unchanged, and
missing files fail loudly with the path. If Orca is not yet running on Linux, start Orca
(or install it) and re-run, or set `ORCA_CLI_COMMAND`.

Then open the project in Orca, start a Coordinator agent terminal, and give it:

```text
Read .orca/START_HERE.md and follow it. Initialize the project, bind or create an Orca
Run, and begin the first planning cycle. Do not implement features until the project
context and initial task plan are sufficiently clear.
```

## First project setup

Edit `docs/PROJECT_CONTEXT.md` before asking the Coordinator to implement product work.
At minimum, define:

- Product/project goal
- Intended users or operators
- Scope and non-goals
- Constraints and acceptance expectations
- Known technology choices (or explicitly state that they are undecided)

The template does not require a technology stack. If a project later chooses one, record
it in `PROJECT_CONTEXT.md` and project-specific docs.

## Operating model

```text
Human
  └─ Coordinator (one active owner, Orca-hosted terminal)
       ├─ Architect Worker (fresh session)
       ├─ Implementer Worker (fresh session)
       ├─ QA Reviewer Worker (fresh session, independent)
       └─ Integrator Worker (fresh session, when needed)
```

The Coordinator plans Tasks, dispatches waves explicitly, waits for results with
`check --wait`, processes and acknowledges each Delivery, settles worker terminals
(reuse / retain / release), and only then ends its turn. It must never end a turn with an
unacknowledged Delivery or a reclaimable terminal, and must not dispatch concurrent Tasks
whose `OWNERSHIP` paths overlap unless worktree isolation or explicit ownership boundaries
make that safe.

## Repository map

```text
.
├── AGENTS.md
├── README.md
├── docs/
│   └── PROJECT_CONTEXT.md
├── scripts/
│   ├── bootstrap.ps1
│   └── bootstrap.sh
└── .orca/
    ├── START_HERE.md
    ├── ORCHESTRATION.md
    ├── COORDINATOR.md
    ├── local/            # runtime-created, gitignored (Run binding, machine-local data)
    ├── workers/
    │   ├── ARCHITECT.md
    │   ├── IMPLEMENTER.md
    │   ├── QA_REVIEWER.md
    │   └── INTEGRATOR.md
    ├── protocols/
    │   ├── TASK_PROTOCOL.md
    │   └── REPORT_PROTOCOL.md
    └── state/
        ├── STATE.md
        ├── CURRENT_TASK.md
        └── reports/
            └── .gitkeep
```

## GitHub Template setup

1. Create a GitHub repository and push this directory.
2. In GitHub repository Settings, enable **Template repository**.
3. For each new project, use **Use this template**.
4. Update `docs/PROJECT_CONTEXT.md`, then run the bootstrap script and start the
   Coordinator as described above.

## Important boundaries

- The Coordinator is the only role that owns the global plan and project-level state.
- Workers send exactly one `worker_done` per dispatch with `--outcome succeeded|failed`,
  always including `--task-id`/`--dispatch-id`, and `--report-path`/`--files-modified`
  with real values. Review verdicts (`APPROVED`/`REJECTED`/`NEEDS_DECISION`) are report
  content only — a completed rejected review still settles `succeeded`.
- A `worker_done` settles the Task/Dispatch automatically; it is a report, not approval,
  and the Coordinator must not re-complete the Task via `task-update`.
- After each settlement the Coordinator chooses exactly one terminal owner: reuse
  (documented exception to the fresh-session rule), `worker-retain`, or `worker-release`.
  Release is post-settlement cleanup, never cancellation.
- Retry a failed dispatch with `worker-start --task <id> --retry-of <dispatch_id>`
  (placement re-specified). Orca circuit-breaks after three failed starts; escalate then,
  never loop.
- QA approval does not replace required tests, security review, or human approval for
  destructive/external actions.
- Never commit secrets, credentials, private tokens, personal data, or machine-local
  runtime state (Run IDs live in `.orca/local/`).

## Version compatibility

This template intentionally avoids pinning Orca internals. Authoritative order:
`orca skills get orchestration` (version-matched guide, plus targeted
`--reference references/<name>.md`) → installed CLI `--help` → official docs → this
template's text. Before a release, re-verify commands against the installed CLI. See
`.orca/ORCHESTRATION.md`.
