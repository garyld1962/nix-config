$ErrorActionPreference = 'Stop'
$registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
$defaultBefore = (Get-ItemProperty $registry).DefaultDistribution
$ubuntuBefore = Get-ChildItem $registry | Get-ItemProperty | Where-Object { $_.DistributionName -eq 'Ubuntu' } | Select-Object PSChildName, BasePath
& wsl.exe -d Ubuntu-Nix-Test --cd / --exec touch /home/gary/reset-probe
if ($LASTEXITCODE -ne 0) { throw 'Cannot create reset probe.' }
& wsl.exe -d Ubuntu-Nix-Test --cd / --exec test -f /home/gary/reset-probe
if ($LASTEXITCODE -ne 0) { throw 'Reset probe was not created.' }
& (Join-Path $PSScriptRoot 'wsl-lab.ps1') -Action Reset
$ubuntuAfter = Get-ChildItem $registry | Get-ItemProperty | Where-Object { $_.DistributionName -eq 'Ubuntu' } | Select-Object PSChildName, BasePath
if (($ubuntuBefore | ConvertTo-Json -Compress) -ne ($ubuntuAfter | ConvertTo-Json -Compress)) { throw 'Source Ubuntu registration changed.' }
if ((Get-ItemProperty $registry).DefaultDistribution -ne $defaultBefore) { throw 'Default WSL distribution changed.' }
Write-Output 'PASS: reset removed the probe, restored the baseline, and preserved the Ubuntu registration and default.'
& wsl.exe --list --verbose
