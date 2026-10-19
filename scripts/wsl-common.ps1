# Shared functions for the WSL developer bootstrap, reset, and lab scripts.
# Targets Windows PowerShell 5.1. Dot-source this file; do not run it.
$ErrorActionPreference = 'Stop'

function Test-UbuntuUsername {
    param([string]$Name)
    [bool]($Name -cmatch '^[a-z][-a-z0-9_]*$' -and $Name.Length -le 32 -and $Name -ne 'root')
}

function Merge-WslConfigMirrored {
    param([Parameter(Mandatory)][string]$Path)
    $result = New-Object 'Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $Path) { $result.AddRange([string[]][IO.File]::ReadAllLines($Path)) }
    $header = -1
    for ($i = 0; $i -lt $result.Count; $i++) {
        if ($result[$i] -imatch '^\s*\[wsl2\]\s*$') { $header = $i; break }
    }
    if ($header -lt 0) {
        if ($result.Count -gt 0) { $result.Add('') }
        $result.Add('[wsl2]')
        $result.Add('networkingMode=mirrored')
    } else {
        $end = $result.Count
        for ($i = $header + 1; $i -lt $result.Count; $i++) {
            if ($result[$i] -match '^\s*\[') { $end = $i; break }
        }
        $key = -1
        for ($i = $header + 1; $i -lt $end; $i++) {
            if ($result[$i] -imatch '^\s*networkingMode\s*=\s*(.*?)\s*$') { $key = $i; break }
        }
        if ($key -ge 0) {
            if ($Matches[1] -ieq 'mirrored') { return $false }
            $result[$key] = 'networkingMode=mirrored'
        } else {
            $result.Insert($header + 1, 'networkingMode=mirrored')
        }
    }
    [IO.File]::WriteAllLines($Path, [string[]]$result)
    $true
}

function Get-Sha256SumsEntry {
    param([Parameter(Mandatory)][string[]]$Lines, [Parameter(Mandatory)][string]$FileName)
    $pattern = "^([a-fA-F0-9]{64})\s+\*?$([regex]::Escape($FileName))$"
    $entries = @($Lines | Where-Object { $_ -match $pattern } | ForEach-Object { ($_ -split '\s+')[0] })
    if ($entries.Count -ne 1) { throw "Expected exactly one checksum entry for $FileName, found $($entries.Count)." }
    $entries[0]
}

function ConvertTo-WslVersion {
    param([string[]]$Lines)
    foreach ($line in @($Lines)) {
        $clean = ($line -replace "`0", '')
        if ($clean -imatch 'WSL version:\s*(\d+\.\d+\.\d+(\.\d+)?)') { return [version]$Matches[1] }
    }
    $null
}

function ConvertFrom-DevSetupMarker {
    param([string]$Content)
    if ($Content -and ($Content.Trim() -cmatch '^dev-setup v1 (\S+)$')) { return $Matches[1] }
    $null
}

function Format-WslStdinPayload {
    param([Parameter(Mandatory)][string]$Script, [string]$SecretLine)
    $payload = ''
    if ($PSBoundParameters.ContainsKey('SecretLine')) { $payload = "IFS= read -r SECRET`n$SecretLine`n" }
    $payload + $Script + "`nexit `$?`n"
}
