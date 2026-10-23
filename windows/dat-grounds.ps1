# Lists which graphics in a 10.98 Tibia.dat are grounds ("Is ground") and full grounds ("Full ground"),
# the same flags Object Builder shows. The result goes to dat-grounds.txt in the project folder, to compare
# with the server's items.otb and the map editor data.
param([string]$Dat = (Join-Path (Split-Path -Parent $PSScriptRoot) 'client\data\things\1098\Tibia.dat'))
$ErrorActionPreference = 'Stop'

$d = [IO.File]::ReadAllBytes($Dat)
$sig = [BitConverter]::ToUInt32($d, 0)
$items = [BitConverter]::ToUInt16($d, 4)
$p = 12

# Flags with extra data, as numbered in 10.10+ files: size of that data in bytes.
$extra = @{ 0 = 2; 8 = 2; 9 = 2; 22 = 4; 25 = 4; 26 = 2; 29 = 2; 30 = 2; 33 = 2; 35 = 2 }
$ground = New-Object System.Collections.Generic.List[int]
$full = New-Object System.Collections.Generic.List[int]

for ($id = 100; $id -le $items; $id++) {
  $isGround = $false; $isFull = $false
  while ($true) {
    $a = $d[$p]; $p++
    if ($a -eq 0xFF) { break }
    if ($a -eq 0) { $isGround = $true }
    if ($a -eq 31) { $isFull = $true }
    if ($a -eq 34) { # market: category, trade as, show as, name, vocation, level
      $p += 6; $len = [BitConverter]::ToUInt16($d, $p); $p += 2 + $len + 4; continue
    }
    if ($extra.ContainsKey([int]$a)) { $p += $extra[[int]$a] }
  }
  $w = $d[$p]; $h = $d[$p + 1]; $p += 2
  if ($w -gt 1 -or $h -gt 1) { $p++ }
  $layers = $d[$p]; $px = $d[$p + 1]; $py = $d[$p + 2]; $pz = $d[$p + 3]; $frames = $d[$p + 4]; $p += 5
  if ($frames -gt 1) { $p += 6 + 8 * $frames }
  $p += 4 * $w * $h * $layers * $px * $py * $pz * $frames
  if ($isGround) { $ground.Add($id) }
  if ($isFull) { $full.Add($id) }
}

function Ranges($list) {
  $out = New-Object System.Text.StringBuilder
  $i = 0
  while ($i -lt $list.Count) {
    $j = $i
    while ($j + 1 -lt $list.Count -and $list[$j + 1] -eq $list[$j] + 1) { $j++ }
    if ($out.Length) { [void]$out.Append(',') }
    if ($j -eq $i) { [void]$out.Append($list[$i]) } else { [void]$out.Append("$($list[$i])-$($list[$j])") }
    $i = $j + 1
  }
  $out.ToString()
}

$report = @(
  ('DAT {0:X8} items {1} end {2}/{3}' -f $sig, $items, $p, $d.Length)
  "GROUND $($ground.Count): $(Ranges $ground)"
  "FULL $($full.Count): $(Ranges $full)"
) -join "`r`n"
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'dat-grounds.txt'
Set-Content -Path $out -Value $report -Encoding ASCII
Write-Host "Is ground: $($ground.Count), Full ground: $($full.Count). Saved to $out"
