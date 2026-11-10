[CmdletBinding()]
param(
    [switch]$SkipOrcaCheck
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "== Orca Development Template bootstrap ==" -ForegroundColor Cyan

if (-not $SkipOrcaCheck) {
    $orca = Get-Command "orca" -ErrorAction SilentlyContinue
    if (-not $orca) {
        throw "Orca CLI was not found. Install/configure Orca separately, then rerun this script."
    }

    Write-Host "`nChecking Orca runtime..."
    & orca status --json
    if ($LASTEXITCODE -ne 0) {
        throw "Orca runtime check failed. Start Orca and verify that 'orca status --json' succeeds."
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
Write-Host "`nNote: this script does not create an AI session. The Coordinator must run inside Orca."
