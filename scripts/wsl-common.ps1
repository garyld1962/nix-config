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

function Test-Elevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Wsl {
    param([Parameter(Mandatory)][string[]]$WslArgs)
    & wsl.exe @WslArgs
    if ($LASTEXITCODE -ne 0) { throw "WSL failed: $($WslArgs -join ' ')" }
}

function Test-WslInstalled {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    $ErrorActionPreference = 'Continue'
    $null = & wsl.exe --status 2>$null
    $LASTEXITCODE -eq 0
}

function Get-WslVersion {
    $ErrorActionPreference = 'Continue'
    $output = @(& wsl.exe --version 2>$null | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) { return $null }
    ConvertTo-WslVersion -Lines $output
}

function Get-WslDistroList {
    $output = @(& wsl.exe --list --quiet)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read WSL distributions.' }
    [string[]]@($output | ForEach-Object { ([string]$_ -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Get-WslDistroBasePath {
    param([Parameter(Mandatory)][string]$Name)
    $entry = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' |
        Get-ItemProperty | Where-Object { $_.DistributionName -eq $Name } | Select-Object -First 1
    if (-not $entry) { return $null }
    [string]$entry.BasePath -replace '^\\\\\?\\', ''
}

function Get-UbuntuWslImage {
    param([Parameter(Mandatory)][string]$Release, [Parameter(Mandatory)][string]$ImageName, [Parameter(Mandatory)][string]$CacheDir)
    $baseUrl = "https://releases.ubuntu.com/$Release"
    $image = Join-Path $CacheDir $ImageName
    $sums = "$image.SHA256SUMS"
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
    & curl.exe --fail --silent --show-error --location --retry 3 --output $sums "$baseUrl/SHA256SUMS"
    if ($LASTEXITCODE -ne 0) { throw 'Checksum download failed.' }
    $expected = Get-Sha256SumsEntry -Lines ([IO.File]::ReadAllLines($sums)) -FileName $ImageName
    if (-not (Test-Path -LiteralPath $image)) {
        Write-Output "Downloading $ImageName to $CacheDir"
        & curl.exe --fail --location --retry 3 --output "$image.partial" "$baseUrl/$ImageName"
        if ($LASTEXITCODE -ne 0) { throw 'Image download failed.' }
        if ((Get-FileHash "$image.partial" -Algorithm SHA256).Hash -ne $expected) { throw 'Downloaded image checksum mismatch.' }
        Move-Item "$image.partial" $image
    } elseif ((Get-FileHash $image -Algorithm SHA256).Hash -ne $expected) {
        throw "Cached image checksum mismatch: $image"
    }
    $image
}

function Import-WslDistro {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$InstallPath, [Parameter(Mandatory)][string]$Image)
    Invoke-Wsl -WslArgs @('--import', $Name, $InstallPath, $Image, '--version', '2')
}

function Invoke-WslBashScript {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Script, [string]$User, [string]$SecretLine)
    $wslArgs = @('-d', $Name)
    if ($User) { $wslArgs += @('-u', $User, '--cd', '/') } else { $wslArgs += @('--cd', '~') }
    $wslArgs += @('--exec', 'bash', '-s')
    $payloadArgs = @{ Script = $Script }
    if ($PSBoundParameters.ContainsKey('SecretLine')) { $payloadArgs.SecretLine = $SecretLine }
    $saved = $OutputEncoding
    try {
        $OutputEncoding = New-Object Text.UTF8Encoding $false
        Format-WslStdinPayload @payloadArgs | & wsl.exe @wslArgs
    } finally {
        $OutputEncoding = $saved
    }
    if ($LASTEXITCODE -ne 0) { throw "Script failed in $Name with exit code $LASTEXITCODE." }
}

function Get-WslFileContent {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Path)
    $ErrorActionPreference = 'Continue'
    $output = @(& wsl.exe -d $Name -u root --exec cat $Path 2>$null | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) { return $null }
    ($output -join "`n") -replace "`0", ''
}

function Get-DevSetupUser {
    param([Parameter(Mandatory)][string]$Name)
    ConvertFrom-DevSetupMarker -Content (Get-WslFileContent -Name $Name -Path '/etc/dev-setup-distro')
}
