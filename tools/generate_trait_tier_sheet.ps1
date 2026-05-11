$ErrorActionPreference = 'Stop'

$path = 'c:\Users\Hydratus\Documents\monster-tamer\docs\trait_brainstorm_080.csv'
$out = 'c:\Users\Hydratus\Documents\monster-tamer\docs\trait_1v1_tier_sheet.md'
$rows = Import-Csv $path

$readNumber = {
    param([string]$s)
    if ([string]::IsNullOrWhiteSpace($s)) { return 0.0 }
    return [double]::Parse($s, [System.Globalization.CultureInfo]::InvariantCulture)
}

$calcStatModsScore = {
    param([string]$mods)
    $score = 0.0
    if ([string]::IsNullOrWhiteSpace($mods)) { return $score }
    $parts = $mods -split '\|'
    foreach ($p in $parts) {
        if ($p -match '^(?<stat>[A-Z_]+):(?<flat>[+-]?\d+(?:\.\d+)?)x(?<mult>[+-]?\d+(?:\.\d+)?)$') {
            $stat = $Matches['stat']
            $flat = [double]::Parse($Matches['flat'], [System.Globalization.CultureInfo]::InvariantCulture)
            $mult = [double]::Parse($Matches['mult'], [System.Globalization.CultureInfo]::InvariantCulture)
            switch ($stat) {
                'MAX_HP' { $score += $flat * 0.03 + (($mult - 1.0) * 8.0) }
                'MAX_ENERGY' { $score += $flat * 0.05 + (($mult - 1.0) * 6.0) }
                'SPEED' { $score += $flat * 0.10 + (($mult - 1.0) * 10.0) }
                'STRENGTH' { $score += $flat * 0.09 + (($mult - 1.0) * 9.0) }
                'MAGIC' { $score += $flat * 0.09 + (($mult - 1.0) * 9.0) }
                'DEFENSE' { $score += $flat * 0.08 + (($mult - 1.0) * 8.0) }
                'RESISTANCE' { $score += $flat * 0.08 + (($mult - 1.0) * 8.0) }
                default { $score += $flat * 0.06 + (($mult - 1.0) * 6.0) }
            }
        }
    }
    return $score
}

$scored = foreach ($r in $rows) {
    $dmgMult = & $readNumber $r.'Damage Multiplier'
    if ($dmgMult -le 0) { $dmgMult = 1.0 }
    $lifesteal = & $readNumber $r.'Lifesteal Ratio'
    $regenHp = & $readNumber $r.'Regen HP Ratio'
    $regenEn = & $readNumber $r.'Regen Energy Ratio'
    $thorns = & $readNumber $r.'Contact Thorns Ratio'
    $activeBelow = & $readNumber $r.'Active Below HP Ratio'
    if ($activeBelow -le 0) { $activeBelow = 1.0 }

    $score = 6.0
    $score += (($dmgMult - 1.0) * 20.0)
    $score += ($lifesteal * 30.0)
    $score += ($regenHp * 24.0)
    $score += ($regenEn * 16.0)
    $score += ($thorns * 18.0)
    $score += (& $calcStatModsScore $r.'Passive Stat Mods')

    if (-not [string]::IsNullOrWhiteSpace($r.'Round Start Stage Mods')) { $score += 1.4 }
    if (-not [string]::IsNullOrWhiteSpace($r.'Contact Stage Mods')) { $score += 1.2 }

    if ($r.'Only When Attacking' -eq 'true') { $score += 0.5 }
    if ($r.'Only When Defending' -eq 'true') { $score += 0.4 }
    if (($r.'Only When Attacking' -ne 'true') -and ($r.'Only When Defending' -ne 'true')) { $score += 0.2 }

    if ($activeBelow -lt 1.0) {
        $score += ((1.0 - $activeBelow) * 3.5)
    }

    if (-not [string]::IsNullOrWhiteSpace($r.'Future Trigger')) { $score += 0.7 }
    if (-not [string]::IsNullOrWhiteSpace($r.'Future Effect')) { $score += 0.9 }

    switch ($r.'Implementation Tier') {
        'current' { $score += 1.0 }
        'hybrid' { $score += 0.5 }
        'future' { $score -= 0.2 }
    }

    $riskText = (($r.Description + ' ' + $r.'Future Effect' + ' ' + $r.Notes)).ToLowerInvariant()
    if ($riskText -match 'lose|self|recoil|random|miss|below|pay|debt') { $score -= 0.4 }
    if ($riskText -match 'gain \+2 priority|guaranteed|revive|survive at 1 hp') { $score += 0.5 }

    $tier = 'C'
    if ($score -ge 13.5) { $tier = 'S' }
    elseif ($score -ge 10.0) { $tier = 'A' }
    elseif ($score -ge 7.2) { $tier = 'B' }

    [PSCustomObject]@{
        ID = [int]$r.ID
        Name = $r.Name
        Element = $r.'Element Filter'
        DamageType = $r.'Damage Type Filter'
        Role = $r.Role
        Impl = $r.'Implementation Tier'
        Score = [Math]::Round($score, 2)
        ScoreText = ([Math]::Round($score, 2)).ToString('0.##', [System.Globalization.CultureInfo]::InvariantCulture)
        Tier = $tier
    }
}

$S = $scored | Where-Object Tier -eq 'S' | Sort-Object Score -Descending
$A = $scored | Where-Object Tier -eq 'A' | Sort-Object Score -Descending
$B = $scored | Where-Object Tier -eq 'B' | Sort-Object Score -Descending
$C = $scored | Where-Object Tier -eq 'C' | Sort-Object Score -Descending

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# 1v1 Trait Tier Sheet')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Generated from docs/trait_brainstorm_080.csv')
[void]$sb.AppendLine(('Date: ' + (Get-Date -Format 'yyyy-MM-dd')))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Scoring intent: quick playtest prioritization for 1v1 trait strength (not a replacement for match data).')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Tier Distribution')
[void]$sb.AppendLine('')
[void]$sb.AppendLine(('- S: ' + $S.Count))
[void]$sb.AppendLine(('- A: ' + $A.Count))
[void]$sb.AppendLine(('- B: ' + $B.Count))
[void]$sb.AppendLine(('- C: ' + $C.Count))
[void]$sb.AppendLine('')

function Add-Section([string]$title, $items, [System.Text.StringBuilder]$builder) {
    [void]$builder.AppendLine(('## ' + $title))
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine('| ID | Name | Impl | Element | Damage Type | Role | Score |')
    [void]$builder.AppendLine('|---:|---|---|---|---|---|---:|')
    foreach ($i in $items) {
        $element = if ([string]::IsNullOrWhiteSpace($i.Element)) { '-' } else { $i.Element }
        $dtype = if ([string]::IsNullOrWhiteSpace($i.DamageType)) { '-' } else { $i.DamageType }
        $role = if ([string]::IsNullOrWhiteSpace($i.Role)) { '-' } else { $i.Role }
        [void]$builder.AppendLine(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f $i.ID, $i.Name, $i.Impl, $element, $dtype, $role, $i.ScoreText))
    }
    [void]$builder.AppendLine('')
}

Add-Section 'S Tier' $S $sb
Add-Section 'A Tier' $A $sb
Add-Section 'B Tier' $B $sb
Add-Section 'C Tier' $C $sb

[void]$sb.AppendLine('## Reading Guide')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('- S: immediate watchlist; likely overtuned or very flexible in 1v1.')
[void]$sb.AppendLine('- A: strong and broadly draftable trait cores.')
[void]$sb.AppendLine('- B: generally fair; often build-dependent or matchup-dependent.')
[void]$sb.AppendLine('- C: niche, high-risk, or currently under-tuned for 1v1 consistency.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Notes')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('- Current traits receive a small reliability bonus; future traits are scored more conservatively.')
[void]$sb.AppendLine('- Raw damage, sustain efficiency, stat amplification, and consistency gates weigh heavily.')
[void]$sb.AppendLine('- Weird high-variance mechanics can still be excellent in play despite lower heuristic scores.')

[System.IO.File]::WriteAllText($out, $sb.ToString(), [System.Text.Encoding]::UTF8)

"Wrote=$out"
"Rows=$($rows.Count)"
"S=$($S.Count) A=$($A.Count) B=$($B.Count) C=$($C.Count)"
