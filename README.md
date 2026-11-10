# Orca Development Template

A technology-agnostic GitHub template for running software projects through **Orca Orchestration**.

> Orca is an external prerequisite. This repository contains project instructions, operating protocols, starter state, and bootstrap scripts. It does not vendor Orca or prescribe a language, framework, database, build system, or deployment platform.

## Principles

- One Coordinator owns the project plan, task graph, decisions, and recovery.
- Each dispatched Worker runs in a fresh agent session. Do not reuse a previous Worker conversation as project memory.
- Pass only task-relevant context to each Worker.
- Persist durable knowledge in repository files and Orca Run/Task/Dispatch records.
- Use independent QA review for meaningful implementation work.
- Keep this template technology-neutral. Project-specific tooling belongs in `docs/PROJECT_CONTEXT.md`.

## Prerequisites

1. Install and configure Orca separately.
2. Enable **Orchestration** in Orca Settings → Experimental if required by your installed version.
3. Ensure `orca status --json` succeeds.
4. Ensure the `orchestration` skill is available to the Coordinator. If needed, retrieve the current guide with `orca skills get orchestration --full`.
5. Open this repository as a project/workspace in Orca and start a Coordinator agent in that workspace.

Orca's CLI and orchestration capabilities evolve. Treat the installed CLI help and current official guide as authoritative; do not assume commands from an older template or blog post remain valid.

## Quick start

### Windows PowerShell

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\bootstrap.ps1
```

Then open the generated project in Orca and give the Coordinator this instruction:

```text
Read .orca/START_HERE.md and follow it. Initialize the project, create or bind
an Orca Run, and begin the first planning cycle. Do not implement features
until the project context and initial task plan are sufficiently clear.
```

### macOS / Linux

```bash
bash scripts/bootstrap.sh
```

Then open the project in Orca and use the same Coordinator instruction above.

The bootstrap scripts validate prerequisites and create missing starter state. They do **not** attempt to launch an AI agent or silently dispatch work: the Coordinator must run inside an Orca agent terminal so Orca can establish the caller identity and inject the correct task/dispatch lifecycle context.

## First project setup

Edit `docs/PROJECT_CONTEXT.md` before asking the Coordinator to implement product work. At minimum, define:

- Product/project goal
- Intended users or operators
- Scope and non-goals
- Constraints and acceptance expectations
- Known technology choices (or explicitly state that they are undecided)

The template does not require a technology stack. If a project later chooses one, record it in `PROJECT_CONTEXT.md` and project-specific docs.

## Operating model

```text
Human
  └─ Coordinator (one active owner)
       ├─ Architect Worker (fresh session)
       ├─ Implementer Worker (fresh session)
       ├─ QA Reviewer Worker (fresh session, independent)
       └─ Integrator Worker (fresh session, when needed)
```

The Coordinator may create multiple independent Tasks before dispatching a parallel wave. It must avoid concurrent edits to the same files unless worktree isolation or explicit ownership boundaries make that safe.

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

1. Create a GitHub repository and upload/push this directory.
2. In GitHub repository Settings, enable **Template repository**.
3. For each new project, use **Use this template**.
4. Update `docs/PROJECT_CONTEXT.md`, then run the bootstrap script and start the Coordinator as described above.

## Important boundaries

- The Coordinator is the only role that owns the global plan and changes project-level state.
- Workers must report completion through Orca's injected lifecycle instructions; include task and dispatch identifiers when the protocol requires them.
- A `worker_done` message is a report, not automatic approval. The Coordinator evaluates the result and dispatch status.
- QA approval does not replace required tests, security review, or human approval for destructive/external actions.
- Never commit secrets, credentials, private tokens, personal data, or local runtime state.
- Do not commit transient Run IDs or machine-specific Orca configuration as universal template defaults.

## Version compatibility

This template intentionally avoids pinning Orca internals. Before a release, verify commands against the installed Orca CLI and current official orchestration guide. See `.orca/ORCHESTRATION.md`.
