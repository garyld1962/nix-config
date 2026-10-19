<#
.SYNOPSIS
Removes a WSL distribution that dev-setup.ps1 created, so dev-setup can be rerun from scratch.
.DESCRIPTION
Refuses any distribution without the dev-setup marker or outside %LOCALAPPDATA%\WSL.
Leaves .wslconfig and the image cache untouched.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$Distro = 'Ubuntu'
)
$ErrorActionPreference = 'Stop'
$common = Join-Path $PSScriptRoot 'scripts\wsl-common.ps1'
if (-not (Test-Path -LiteralPath $common)) { throw "dev-reset needs $common; run it from a clone of the repository." }
. $common

if (Test-Elevated) { throw 'Run dev-reset from a normal (not elevated) PowerShell window.' }
if (-not ((Get-WslDistroList) -contains $Distro)) { throw "'$Distro' is not registered." }
if (-not (Get-DevSetupUser -Name $Distro)) { throw 'dev-reset only removes distributions created by dev-setup.' }
$expected = Join-Path $env:LOCALAPPDATA "WSL\$Distro"
$actual = Get-WslDistroBasePath -Name $Distro
if ([string]$actual.TrimEnd('\') -ine $expected.TrimEnd('\')) {
    throw "'$Distro' is installed at '$actual', not the dev-setup location '$expected'. Refusing to remove it."
}

Write-Output "This deletes the WSL distribution '$Distro' and everything inside it:", "  $expected"
if ((Read-Host "Type $Distro to confirm") -cne $Distro) { Write-Output 'Cancelled.'; return }

& wsl.exe --terminate $Distro
Invoke-Wsl -WslArgs @('--unregister', $Distro)
if (Test-Path -LiteralPath $expected) { Remove-Item -LiteralPath $expected -Recurse -Force }
Write-Output "Removed $Distro."
