param(
	[string]$GodotExe = "",
	[string]$ProjectPath = "",
	[switch]$Fix,
	[switch]$NoBalanceWarnings
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "battle_test_common.ps1")

$ProjectPath = Resolve-BattleTestProjectPath -ProjectPath $ProjectPath -ScriptRoot $PSScriptRoot
$GodotExe = Resolve-BattleTestGodotExe -GodotExe $GodotExe

if ([string]::IsNullOrWhiteSpace($GodotExe)) {
	Write-Error "Godot executable not found. Pass -GodotExe with full path."
}

Write-Host ("Running monster learnset validation with: " + $GodotExe)
Write-Host ("Project: " + $ProjectPath)

$godotArgs = @(
	"--headless",
	"--path", $ProjectPath,
	"--script", "res://tools/validate_monster_learnsets.gd"
)

$userArgs = @()
if ($Fix) {
	$userArgs += "--fix"
}
if ($NoBalanceWarnings) {
	$userArgs += "--no-balance-warnings"
}
if ($userArgs.Count -gt 0) {
	$godotArgs += "--"
	$godotArgs += $userArgs
}

& $GodotExe @godotArgs
$exitCode = $LASTEXITCODE
exit $exitCode