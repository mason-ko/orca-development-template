# Repository-wide Agent Rules

These rules apply to every agent working in this repository.

## Operating rules

1. Follow `.orca/START_HERE.md`, `.orca/ORCHESTRATION.md`, and the relevant role file.
2. The Coordinator owns global planning, task assignment, state transitions, and acceptance decisions.
3. Every dispatched Worker must be a fresh agent session unless the Coordinator explicitly documents a justified exception.
4. Do not assume prior chat history exists. Read only the files and task context needed for the assigned work.
5. Do not expand scope without Coordinator approval.
6. Do not invent project requirements, technology choices, test results, or completion status.
7. Preserve existing conventions. If no convention exists, propose the smallest reasonable choice and record it.
8. Never expose or commit secrets. Do not run destructive commands or external side effects without explicit authorization.

## Worker boundaries

- Work only within the assigned scope and owned files.
- Ask the Coordinator through Orca when a blocking decision is required.
- Do not mark another Task complete or alter global project status.
- Report changed files, checks performed, results, risks, and remaining work.
- Do not claim a test passed unless it was actually executed and its result observed.

## Technology neutrality

No language, framework, package manager, database, CI provider, or deployment target is mandated by this template. Follow `docs/PROJECT_CONTEXT.md` and project-specific instructions.
