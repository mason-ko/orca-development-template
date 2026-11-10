[CmdletBinding()]
param(
    [switch]$SkipOrcaCheck
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "== Orca Development Template bootstrap (v1.0.1) ==" -ForegroundColor Cyan

# Resolve a safe Orca executable: ORCA_CLI_COMMAND wins, then bare `orca`.
# On Windows bare `orca` is the Orca CLI; the GNOME screen-reader hazard is Linux-only.
if (-not $SkipOrcaCheck) {
    if ($env:ORCA_CLI_COMMAND) {
        $orcaCmd = $env:ORCA_CLI_COMMAND
        if (-not (Get-Command $orcaCmd -ErrorAction SilentlyContinue)) {
            throw "ORCA_CLI_COMMAND is set but not executable: $orcaCmd"
        }
    } else {
        $found = Get-Command "orca" -ErrorAction SilentlyContinue
        if (-not $found) {
            throw "Orca CLI was not found. Install/configure Orca separately (or set ORCA_CLI_COMMAND), then rerun this script."
        }
        $orcaCmd = $found.Source
    }

    Write-Host "`nChecking Orca runtime via: $orcaCmd"
    & $orcaCmd status --json
    if ($LASTEXITCODE -ne 0) {
        throw "Orca runtime check failed. Start Orca and verify that 'status --json' succeeds with: $orcaCmd"
    }
}

$contextPath = Join-Path $RepoRoot "docs/PROJECT_CONTEXT.md"
$statePath = Join-Path $RepoRoot ".orca/state/STATE.md"
$currentTaskPath = Join-Path $RepoRoot ".orca/state/CURRENT_TASK.md"

foreach ($path in @($contextPath, $statePath, $currentTaskPath)) {
    if (-not (Test-Path $path)) {
        throw "Required template file is missing: $path"
    }
}

Write-Host "`nBootstrap checks passed." -ForegroundColor Green
Write-Host "Next:"
Write-Host "  1. Edit docs/PROJECT_CONTEXT.md"
Write-Host "  2. Open this repository as an Orca workspace"
Write-Host "  3. Start a Coordinator agent terminal"
Write-Host "  4. Ask it to read .orca/START_HERE.md and follow the startup sequence"
Write-Host "`nNote: this script verifies prerequisites only. It does not create files,"
Write-Host "start an AI session, or dispatch work. The Coordinator must run inside Orca."
