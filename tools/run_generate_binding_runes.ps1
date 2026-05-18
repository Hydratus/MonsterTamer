$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$godotExe = "godot"

Push-Location $repoRoot
try {
    & $godotExe --headless --script "res://tools/generate_binding_runes.gd"
}
finally {
    Pop-Location
}
