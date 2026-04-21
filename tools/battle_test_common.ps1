function Resolve-BattleTestProjectPath {
    param(
        [string]$ProjectPath,
        [string]$ScriptRoot
    )

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        return (Resolve-Path (Join-Path $ScriptRoot "..")).Path
    }

    return $ProjectPath
}

function Initialize-BattleTestLogDir {
    param(
        [string]$ProjectPath,
        [string]$LogDir
    )

    if ([string]::IsNullOrWhiteSpace($LogDir)) {
        $LogDir = Join-Path $ProjectPath "docs\qa\logs"
    }

    if (-not (Test-Path -LiteralPath $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir | Out-Null
    }

    return $LogDir
}

function Resolve-BattleTestGodotExe {
    param(
        [string]$GodotExe
    )

    if (-not [string]::IsNullOrWhiteSpace($GodotExe)) {
        return $GodotExe
    }

    $candidateNames = @(
        "godot.exe",
        "Godot_v4.6-stable_win64_console.exe",
        "Godot_v4.6-stable_win64.exe"
    )

    foreach ($name in $candidateNames) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) {
            return $cmd.Source
        }
    }

    return ""
}
