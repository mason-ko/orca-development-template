# Current Task

- **Task ID (runtime hint, machine-local):** NONE
- **Dispatch ID (runtime hint, machine-local):** NONE
- **Title:** NONE
- **Role:** NONE
- **Status:** IDLE
- **Acceptance criteria:** N/A
- **Relevant context:** N/A
- **Report:** N/A

The Coordinator updates this file when a task becomes active and clears it when the task
is complete. Runtime IDs here are convenience hints for the machine that ran the Run; they
are not portable. After a resume on another machine, re-derive authoritative state from
Orca (`run-list` / `run-use`, `task-list`, `dispatch-show`) instead of trusting these IDs.
