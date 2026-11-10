#!/usr/bin/env bash
# Orca Development Template bootstrap (v1.0.1)
# Verifies prerequisites only: resolves a SAFE Orca executable, checks runtime,
# and confirms starter-state files exist. Creates nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== Orca Development Template bootstrap (v1.0.1) =="

# Resolve the Orca executable. Never run bare `orca` on Linux outside an
# Orca-managed terminal: there it is normally the GNOME screen reader
# (/usr/bin/orca) and would start speech on the user's machine.
OS="$(uname -s)"
ORCA_BIN=""

if [[ -n "${ORCA_CLI_COMMAND:-}" ]]; then
  if command -v "$ORCA_CLI_COMMAND" >/dev/null 2>&1; then
    ORCA_BIN="$ORCA_CLI_COMMAND"
  else
    echo "ERROR: ORCA_CLI_COMMAND is set but not executable: $ORCA_CLI_COMMAND" >&2
    exit 1
  fi
elif command -v orca-ide >/dev/null 2>&1; then
  ORCA_BIN="orca-ide"
elif [[ "$OS" == "Linux" ]]; then
  echo "ERROR: no safe Orca executable found on Linux." >&2
  echo "Bare 'orca' on Linux is normally the GNOME screen reader and will not be run." >&2
  echo "Install the Orca IDE (providing 'orca-ide'), start Orca, or set ORCA_CLI_COMMAND" >&2
  echo "to the Orca CLI path, then rerun this script." >&2
  exit 1
elif command -v orca >/dev/null 2>&1; then
  # macOS and similar: bare orca is the Orca CLI (no GNOME screen-reader conflict).
  ORCA_BIN="orca"
else
  echo "ERROR: Orca CLI not found (tried ORCA_CLI_COMMAND, orca-ide, orca)." >&2
  echo "Install/configure Orca separately, then rerun this script." >&2
  exit 1
fi

echo
echo "Checking Orca runtime via: $ORCA_BIN"
if ! "$ORCA_BIN" status --json; then
  echo "ERROR: Orca runtime check failed with '$ORCA_BIN'. Start Orca and rerun." >&2
  exit 1
fi

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
echo "Note: this script verifies prerequisites only. It creates no files, starts no AI"
echo "session, and dispatches no work. The Coordinator must run inside Orca."
