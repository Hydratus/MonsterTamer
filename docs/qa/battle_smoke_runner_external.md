# External Battle Smoke Runner

## Why
Run smoke tests outside VS Code to avoid editor crashes during headless execution.

## Script
- `tools/run_battle_smoke_external.ps1`

## Quick Start (PowerShell)
From project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_battle_smoke_external.ps1 -FailsOnly -NoJson
```

## With explicit Godot path
```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_battle_smoke_external.ps1 -GodotExe "C:\\Tools\\Godot_v4.6-stable_win64_console.exe" -FailsOnly -NoJson
```

## Output
- Exit code `0`: all tests passed
- Exit code `1`: one or more tests failed
- Logs are written to `docs/qa/logs/`

## Notes
- Uses `res://core/battle/tests/run_battle_smoke_tests.gd`
- Supports optional flags:
  - `-FailsOnly` -> forwards `--fails-only`
  - `-NoJson` -> forwards `--no-json`
