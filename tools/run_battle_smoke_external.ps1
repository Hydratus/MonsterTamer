param(
    [string]$GodotExe = "",
    [string]$ProjectPath = "",
    [switch]$FailsOnly,
    [switch]$NoJson,
    [string]$LogDir = "",
    [switch]$StreamToTerminal,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "battle_test_common.ps1")

$ProjectPath = Resolve-BattleTestProjectPath -ProjectPath $ProjectPath -ScriptRoot $PSScriptRoot
$LogDir = Initialize-BattleTestLogDir -ProjectPath $ProjectPath -LogDir $LogDir
$GodotExe = Resolve-BattleTestGodotExe -GodotExe $GodotExe

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
    Write-Error "Godot executable not found. Pass -GodotExe with full path."
}

Write-Host ("Running battle smoke tests with: " + $GodotExe)
Write-Host ("Project: " + $ProjectPath)

$batFile = Join-Path $PSScriptRoot "run_battle_smoke_detached.bat"
$batArgs = @("/c", ('"{0}" "{1}"' -f $batFile, $ProjectPath))
if ($FailsOnly) {
    $batArgs += "--fails-only"
}
if ($NoJson) {
    $batArgs += "--no-json"
}

& cmd.exe @batArgs
$exitCode = $LASTEXITCODE

exit $exitCode
