# Report Protocol

Every Worker report must be concise, evidence-based, and saved to the path specified by
the Coordinator (under `.orca/state/reports/`).

```markdown
# <Task title> — <Role> Report

- Task ID: <runtime task id>
- Dispatch ID: <runtime dispatch id>
- Report outcome: SUCCEEDED / FAILED / BLOCKED
- Date:

## Summary
<What was done or found>

## Files
- `path`: <change or finding>

## Verification
| Command/check | Result | Evidence |
|---|---|---|
| ... | PASS/FAIL/NOT RUN | ... |

## Acceptance criteria
- [x] / [ ] <criterion> — <evidence>

## Risks and limitations
- None / ...

## Remaining work
- None / ...
```

## Report outcome vs lifecycle outcome

These are two different layers. Do not mix them.

| Layer | Vocabulary | Meaning |
|---|---|---|
| Report outcome | `SUCCEEDED` / `FAILED` / `BLOCKED` | Narrative status of the attempted work |
| `worker_done --outcome` | `succeeded` / `failed` **only** | Whether the Dispatch completed. Orca has no third value; `BLOCKED` is not a valid lifecycle outcome |

Rules:

- A completed report is `worker_done --outcome succeeded` — even when acceptance criteria
  remain unmet or the QA verdict is negative; unmet criteria and blockers are described in
  the report.
- `--outcome failed` only when the dispatch could not complete its work at all.
- While blocked, use Orca `ask` or escalation; if the block makes completion impossible,
  send `--outcome failed` with the reason and report what you have.
- QA verdicts (`APPROVED` / `REJECTED` / `NEEDS_DECISION`) live in the report only. A
  completed `REJECTED` review is `--outcome succeeded`.
- Task-level `blocked` / `failed` statuses are the Coordinator's responsibility via
  `task-update`, never the Worker's lifecycle message.

## worker_done fields

Send exactly one `worker_done` for the dispatch, following the injected preamble:

- Always: `--task-id <task_id> --dispatch-id <dispatch_id>` and `--outcome succeeded|failed`.
- When applicable with real values: `--files-modified <csv>` and
  `--report-path <path>` — the report path lets the Coordinator and the next Worker (e.g.
  QA) find the artifact without manual cross-referencing.

A report is not a substitute for `worker_done`, and `worker_done` is not approval: the
Coordinator evaluates the report and settles the terminal per
`.orca/ORCHESTRATION.md` §Settlement accounting.
