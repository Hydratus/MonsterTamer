param(
    [string]$GodotExe = "",
    [string]$ProjectPath = "",
    [switch]$FailsOnly,
    [switch]$NoJson,
    [string]$LogDir = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $LogDir = Join-Path $ProjectPath "docs\qa\logs"
}

if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    $candidateNames = @(
        "godot.exe",
        "Godot_v4.6-stable_win64_console.exe",
        "Godot_v4.6-stable_win64.exe"
    )
    foreach ($name in $candidateNames) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd -ne $null) {
            $GodotExe = $cmd.Source
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    Write-Error "Godot executable not found. Pass -GodotExe with full path."
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = Join-Path $LogDir ("battle_smoke_" + $timestamp + ".log")

$args = @(
    "--headless",
    "--path", $ProjectPath,
    "--script", "res://core/battle/tests/run_battle_smoke_tests.gd",
    "--"
)

if ($FailsOnly) {
    $args += "--fails-only"
}
if ($NoJson) {
    $args += "--no-json"
}

Write-Host ("Running battle smoke tests with: " + $GodotExe)
Write-Host ("Project: " + $ProjectPath)
Write-Host ("Log: " + $logFile)

& $GodotExe @args 2>&1 | Tee-Object -FilePath $logFile
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    Write-Host "Battle smoke runner finished: PASS"
} else {
    Write-Host ("Battle smoke runner finished: FAIL (exit " + $exitCode + ")")
}

exit $exitCode
