# Report Protocol

Every Worker report should be concise, evidence-based, and saved to the path specified by the Coordinator.

```markdown
# <Task title> — <Role> Report

- Task ID:
- Dispatch ID:
- Outcome: SUCCEEDED / FAILED / BLOCKED
- Date:

## Summary
<What was done or found>

## Files
- `path`: <change or finding>

## Verification
| Command/check | Result | Evidence |
|---|---|---|
| TODO | PASS/FAIL/NOT RUN | TODO |

## Acceptance criteria
- [x] / [ ] <criterion> — <evidence>

## Risks and limitations
- None / TODO

## Remaining work
- None / TODO
```

QA reports must additionally include a primary verdict: `APPROVED`, `REJECTED`, or `NEEDS_DECISION`, with findings ordered by severity.

A report is not a substitute for Orca's required `worker_done` message. Follow the injected dispatch instructions for completion signaling.
