$rows = Import-Csv 'data/elements/type_chart.csv' -Delimiter ';'
$elements = $rows.Element
$map = @{ 'x0' = 0.0; 'x0,5' = 0.5; 'x1' = 1.0; 'x2' = 2.0 }
$inv = @{ 0.0='x0'; 0.5='x0,5'; 1.0='x1'; 2.0='x2' }

$results = foreach($row in $rows){
  $a = $row.Element
  $vals = @($elements | ForEach-Object { $map[$row.$_] })
  $inc = @($rows | ForEach-Object { $map[$_.$a] })
  $off = ($vals | Measure-Object -Average).Average
  $def = ($inc | Measure-Object -Average).Average
  [pscustomobject]@{
    Element=$a; Off2=(@($vals|Where-Object{$_ -eq 2.0}).Count); Off05=(@($vals|Where-Object{$_ -eq 0.5}).Count); Off0=(@($vals|Where-Object{$_ -eq 0.0}).Count);
    DefIn2=(@($inc|Where-Object{$_ -eq 2.0}).Count); DefIn05=(@($inc|Where-Object{$_ -eq 0.5}).Count); DefIn0=(@($inc|Where-Object{$_ -eq 0.0}).Count);
    OffAvg=[math]::Round($off,3); DefAvg=[math]::Round($def,3); Score=[math]::Round($off-$def,3)
  }
}

$sorted = $results | Sort-Object Score -Descending, Element
$mutual = @()
for($i=0; $i -lt $elements.Count; $i++){
  for($j=$i+1; $j -lt $elements.Count; $j++){
    $a = $elements[$i]; $b = $elements[$j]
    $ar = $rows | Where-Object Element -eq $a
    $br = $rows | Where-Object Element -eq $b
    if($map[$ar.$b] -eq 2.0 -and $map[$br.$a] -eq 2.0){
      $mutual += [pscustomobject]@{A=$a;B=$b}
    }
  }
}

$noDef05 = $results | Where-Object DefIn05 -eq 0 | Sort-Object Element | Select-Object -ExpandProperty Element
$top3 = $sorted | Select-Object -First 3
$bottom3 = $sorted | Select-Object -Last 3
$baseSpread = [math]::Round((($sorted|Select-Object -First 1).Score - ($sorted|Select-Object -Last 1).Score),3)

# one-step up towards x2 for positive effect on low scorers / defenders
$stepUp = @{ 0.0=0.5; 0.5=1.0; 1.0=2.0; 2.0=2.0 }
$candidates = @()
$n = $elements.Count
foreach($row in $rows){
  $a = $row.Element
  foreach($b in $elements){
    $cur = $map[$row.$b]
    $new = $stepUp[$cur]
    if($new -eq $cur){ continue }
    $delta = ($new - $cur) / $n
    $scoreA = ($sorted | Where-Object Element -eq $a).Score + $delta
    $scoreB = ($sorted | Where-Object Element -eq $b).Score - $delta
    $scores = foreach($r in $sorted){
      if($r.Element -eq $a){$scoreA}
      elseif($r.Element -eq $b){$scoreB}
      else{$r.Score}
    }
    $newSpread = [math]::Round((($scores|Measure-Object -Maximum).Maximum - ($scores|Measure-Object -Minimum).Minimum),3)
    $candidates += [pscustomobject]@{A=$a;B=$b;From=$inv[$cur];To=$inv[$new];NewSpread=$newSpread;Delta=[math]::Round($baseSpread-$newSpread,3)}
  }
}
$best = $candidates | Sort-Object Delta -Descending, NewSpread, A, B | Select-Object -First 10

[pscustomobject]@{Sorted=$sorted;MutualX2=$mutual;NoDef05=$noDef05;Top3=$top3;Bottom3=$bottom3;BaseSpread=$baseSpread;BestCandidates=$best} | ConvertTo-Json -Depth 8 | Set-Content '.tmp_type_analysis.json'
'OK'
