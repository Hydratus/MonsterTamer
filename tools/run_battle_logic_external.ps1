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
$LogDir = Ensure-BattleTestLogDir -ProjectPath $ProjectPath -LogDir $LogDir
$GodotExe = Resolve-BattleTestGodotExe -GodotExe $GodotExe

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	Write-Error "Godot executable not found. Pass -GodotExe with full path."
}

Write-Host ("Running battle logic tests with: " + $GodotExe)
Write-Host ("Project: " + $ProjectPath)

$batFile = Join-Path $PSScriptRoot "run_battle_logic_detached.bat"
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