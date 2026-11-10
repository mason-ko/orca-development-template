# Task Protocol

Use this structure when creating an Orca Task (`task-create --spec`). Keep the
specification self-contained and concise: a Worker in a fresh session must be able to do
the job from this spec plus the listed context alone.

```text
TITLE: <short outcome>

OBJECTIVE:
<one measurable outcome>

CONTEXT:
- <specific document/path>
- <specific decision/report path>

SCOPE:
- In: <owned work>
- Out: <explicit exclusions>

OWNERSHIP:
- Expected role: <Architect | Implementer | QA Reviewer | Integrator>
- Allowed paths: <paths or discovery boundary>

ACCEPTANCE CRITERIA:
- [ ] <observable condition>
- [ ] <observable condition>

VERIFICATION:
- <checks to run, or explain why unavailable>

DELIVERABLE:
- Report path: .orca/state/reports/<task-id>-<role>.md
- Include changed files, checks, evidence, risks, and remaining work.

CONSTRAINTS:
- Fresh Worker session.
- Do not exceed assigned scope.
- Ask Coordinator through Orca for blocking decisions.
```

Rules:

- Do not include the entire project history. Link only the context needed for this task;
  link prior reports by path, never by pasted transcript.
- `OWNERSHIP.Allowed paths` is the concurrency contract: before dispatching a parallel
  wave, the Coordinator compares it against every active Dispatch's allowed paths
  (`.orca/ORCHESTRATION.md` §Parallel waves and ownership). If overlap exists, serialize,
  merge the Tasks, or isolate worktrees.
- For rework after a QA `REJECTED`, the fix Task must reference the QA report path and the
  rejection criteria verbatim enough that the new Implementer needs no conversation
  history.
