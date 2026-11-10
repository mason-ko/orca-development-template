#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Orca Development Template bootstrap =="

if ! command -v orca >/dev/null 2>&1; then
  echo "ERROR: Orca CLI not found. Install/configure Orca separately, then rerun." >&2
  exit 1
fi

echo
echo "Checking Orca runtime..."
orca status --json

for file in docs/PROJECT_CONTEXT.md .orca/state/STATE.md .orca/state/CURRENT_TASK.md; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: Required template file missing: $file" >&2
    exit 1
  fi
done

echo
echo "Bootstrap checks passed."
echo "Next:"
echo "  1. Edit docs/PROJECT_CONTEXT.md"
echo "  2. Open this repository as an Orca workspace"
echo "  3. Start a Coordinator agent terminal"
echo "  4. Ask it to read .orca/START_HERE.md and follow the startup sequence"
echo
echo "Note: this script does not create an AI session. The Coordinator must run inside Orca."
