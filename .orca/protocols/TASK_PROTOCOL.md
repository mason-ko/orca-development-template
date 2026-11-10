# Task Protocol

Use this structure when creating an Orca Task. Keep the specification self-contained and concise.

```text
TITLE: <short outcome>

OBJECTIVE:
<one measurable outcome>

CONTEXT:
- <specific document/path>
- <specific decision/report>

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

Do not include the entire project history. Link only the context needed for this task.
