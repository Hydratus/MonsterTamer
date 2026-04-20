param(
    [string]$ProjectPath = "",
    [switch]$NoJson
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

Write-Host "Running Godot smoke tests in detached process (prevents terminal freeze)..."
Write-Host "Project: $ProjectPath"

# Run batch file in completely detached cmd process
$logDir = Join-Path $ProjectPath "docs\qa\logs"
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Call batch file - this runs detached and won't freeze PowerShell
$batFile = Join-Path $PSScriptRoot "run_battle_smoke_detached.bat"
$exitCode = 0

try {
    # Execute batch file directly (runs in separate process)
    & cmd.exe /c "`"$batFile`" `"$ProjectPath`""
    $exitCode = $LASTEXITCODE
} catch {
    Write-Error "Failed to run smoke tests: $_"
    exit 1
}

# Show latest log summary
$latest = Get-ChildItem -LiteralPath $logDir -Filter "battle_smoke_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latest) {
    Write-Host "`nTest log: $($latest.FullName)"
    Write-Host "Test results:"
    Select-String -Path $latest.FullName -Pattern "tests passed|tests failed|PASS|FAIL" -CaseSensitive:$false | ForEach-Object { Write-Host "  $_" }
}

exit $exitCode
