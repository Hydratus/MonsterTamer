param(
    [string]$CsvPath = 'c:\Users\Hydratus\Documents\monster-tamer\docs\attack_brainstorm_150.csv',
    [string]$MovesRoot = 'c:\Users\Hydratus\Documents\monster-tamer\data\moves',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $CsvPath)) {
    throw "CSV not found: $CsvPath"
}
if (-not (Test-Path $MovesRoot)) {
    throw "Moves folder not found: $MovesRoot"
}

$statusMap = @{
    'none' = 0
    'burn' = 1
    'wet' = 2
    'poison' = 3
    'bleed' = 4
    'blind' = 5
    'daze' = 6
    'silence' = 7
    'root' = 8
    'bind' = 9
    'sleep' = 10
    'freeze' = 11
    'paralyze' = 12
    'paralysis' = 12
    'fear' = 13
    'stagger' = 14
    'cursed' = 15
    'curse' = 15
    'cleanse' = 16
}

function ConvertTo-StatusChance([string]$raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return 0.0 }
    $value = [double]::Parse($raw, [System.Globalization.CultureInfo]::InvariantCulture)
    if ($value -gt 1.0) { $value = $value / 100.0 }
    if ($value -lt 0.0) { $value = 0.0 }
    if ($value -gt 1.0) { $value = 1.0 }
    return [Math]::Round($value, 4)
}

function Get-MoveNameFromTres([string]$filePath) {
    $line = Get-Content $filePath | Where-Object { $_ -match '^name\s*=\s*"' } | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace '^name\s*=\s*"', '' -replace '"\s*$', '').Trim()
}

function Set-ResourceLine([System.Collections.Generic.List[string]]$lines, [string]$key, [string]$value) {
    $index = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^' + [Regex]::Escape($key) + '\s*=')) {
            $index = $i
            break
        }
    }

    $newLine = "$key = $value"
    if ($index -ge 0) {
        $lines[$index] = $newLine
        return
    }

    $resourceIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '[resource]') {
            $resourceIndex = $i
            break
        }
    }

    if ($resourceIndex -ge 0) {
        $insertAt = $resourceIndex + 1
        while ($insertAt -lt $lines.Count -and $lines[$insertAt].Trim() -ne '') {
            $insertAt++
        }
        $lines.Insert($insertAt, $newLine)
    } else {
        $lines.Add('[resource]')
        $lines.Add($newLine)
    }
}

$rows = Import-Csv $CsvPath
$rowsWithStatus = $rows | Where-Object { $_.'Status Effect' -and $_.'Status Effect'.Trim() -ne '' }

$csvByName = @{}
foreach ($row in $rowsWithStatus) {
    $key = $row.Name.Trim().ToLowerInvariant()
    if (-not $csvByName.ContainsKey($key)) {
        $csvByName[$key] = $row
    }
}

$files = Get-ChildItem $MovesRoot -Recurse -Filter *.tres
$updated = 0
$matched = 0
$unmapped = [System.Collections.Generic.List[string]]::new()
$unknownStatuses = [System.Collections.Generic.HashSet[string]]::new()

foreach ($f in $files) {
    $moveName = Get-MoveNameFromTres $f.FullName
    if ([string]::IsNullOrWhiteSpace($moveName)) { continue }

    $lookup = $moveName.Trim().ToLowerInvariant()
    if (-not $csvByName.ContainsKey($lookup)) { continue }

    $matched++
    $row = $csvByName[$lookup]

    $statusKey = $row.'Status Effect'.Trim().ToLowerInvariant()
    if (-not $statusMap.ContainsKey($statusKey)) {
        [void]$unknownStatuses.Add($statusKey)
        continue
    }

    $statusEnum = [int]$statusMap[$statusKey]
    $statusChance = ConvertTo-StatusChance $row.'Status Chance'

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content $f.FullName))

    Set-ResourceLine $lines 'status_effect' $statusEnum
    Set-ResourceLine $lines 'status_chance' ($statusChance.ToString('0.####', [System.Globalization.CultureInfo]::InvariantCulture))
    Set-ResourceLine $lines 'status_duration' '0'
    Set-ResourceLine $lines 'status_target_self' 'false'

    if (-not $DryRun) {
        Set-Content -Path $f.FullName -Value $lines -Encoding UTF8
    }
    $updated++
}

foreach ($row in $rowsWithStatus) {
    $name = $row.Name.Trim()
    $key = $name.ToLowerInvariant()
    $hasMatch = $false
    foreach ($f in $files) {
        $moveName = Get-MoveNameFromTres $f.FullName
        if ($moveName -and $moveName.Trim().ToLowerInvariant() -eq $key) {
            $hasMatch = $true
            break
        }
    }
    if (-not $hasMatch) {
        $unmapped.Add($name)
    }
}

"CSVStatusRows=$($rowsWithStatus.Count)"
"MatchedByName=$matched"
"UpdatedFiles=$updated"
"DryRun=$($DryRun.IsPresent)"
if ($unknownStatuses.Count -gt 0) {
    "UnknownStatuses=" + (($unknownStatuses | Sort-Object) -join ', ')
}
"UnmappedCount=$($unmapped.Count)"
$unmapped | Select-Object -First 25
