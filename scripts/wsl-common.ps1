# Shared functions for the WSL developer bootstrap, reset, and lab scripts.
# Targets Windows PowerShell 5.1. Dot-source this file; do not run it.
$ErrorActionPreference = 'Stop'

function Test-UbuntuUsername {
    param([string]$Name)
    [bool]($Name -cmatch '^[a-z][-a-z0-9_]*$' -and $Name.Length -le 32 -and $Name -ne 'root')
}

function Find-WslConfigNetworkingMode {
    # Locates the [wsl2] section and its networkingMode key. Indices are -1 when absent.
    param([string[]]$Lines)
    $found = [pscustomobject]@{ Header = -1; End = @($Lines).Count; Key = -1; Value = $null }
    for ($i = 0; $i -lt @($Lines).Count; $i++) {
        if ($Lines[$i] -imatch '^\s*\[wsl2\]\s*$') { $found.Header = $i; break }
    }
    if ($found.Header -lt 0) { return $found }
    for ($i = $found.Header + 1; $i -lt @($Lines).Count; $i++) {
        if ($Lines[$i] -match '^\s*\[') { $found.End = $i; break }
    }
    for ($i = $found.Header + 1; $i -lt $found.End; $i++) {
        if ($Lines[$i] -imatch '^\s*networkingMode\s*=\s*(.*?)\s*$') { $found.Key = $i; $found.Value = $Matches[1]; break }
    }
    $found
}

function Get-WslConfigNetworkingMode {
    param([string[]]$Lines)
    (Find-WslConfigNetworkingMode -Lines $Lines).Value
}

function Merge-WslConfigMirrored {
    param([Parameter(Mandatory)][string]$Path)
    $result = New-Object 'Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $Path) { $result.AddRange([string[]][IO.File]::ReadAllLines($Path)) }
    $found = Find-WslConfigNetworkingMode -Lines ([string[]]$result)
    if ($found.Header -lt 0) {
        if ($result.Count -gt 0) { $result.Add('') }
        $result.Add('[wsl2]')
        $result.Add('networkingMode=mirrored')
    } elseif ($found.Key -ge 0) {
        if ($found.Value -ieq 'mirrored') { return $false }
        $result[$found.Key] = 'networkingMode=mirrored'
    } else {
        $result.Insert($found.Header + 1, 'networkingMode=mirrored')
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
    # Output is localized; the WSL version is the first line that carries a version number.
    foreach ($line in @($Lines)) {
        $clean = ($line -replace "`0", '').Trim()
        if (-not $clean) { continue }
        if ($clean -match '(\d+\.\d+\.\d+(\.\d+)?)') { return [version]$Matches[1] }
        return $null
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
    # The secret travels base64-encoded so the console's output encoding cannot alter it.
    # bash -s runs the first stdin line as script, so the read line precedes the secret.
    $payload = ''
    if ($PSBoundParameters.ContainsKey('SecretLine')) {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($SecretLine))
        $payload = "IFS= read -r SECRET_B64`n$encoded`nSECRET=`$(printf %s `"`$SECRET_B64`" | base64 -d); unset SECRET_B64`n"
    }
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
    if ($LASTEXITCODE -eq 0) { return $true }
    $null = & wsl.exe --version 2>$null
    $LASTEXITCODE -eq 0
}

function Get-WslVersion {
    $ErrorActionPreference = 'Continue'
    $output = @(& wsl.exe --version 2>$null | ForEach-Object { [string]$_ })
    if ($LASTEXITCODE -ne 0) { return $null }
    ConvertTo-WslVersion -Lines $output
}

function Get-WslDistroList {
    # The registry is the source wsl.exe itself uses; `wsl --list` exits non-zero when no distribution exists.
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    if (-not (Test-Path $key)) { return [string[]]@() }
    [string[]]@(Get-ChildItem $key | Get-ItemProperty | ForEach-Object { [string]$_.DistributionName } | Where-Object { $_ })
}

function Get-WslDistroBasePath {
    param([Parameter(Mandatory)][string]$Name)
    $entry = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' |
        Get-ItemProperty | Where-Object { $_.DistributionName -eq $Name } | Select-Object -First 1
    if (-not $entry -or -not $entry.BasePath) { return $null }
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
        Write-Host "Downloading $ImageName to $CacheDir"
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
    # Windows PowerShell prefixes the piped payload with a UTF-8 BOM when the console code page is 65001,
    # which would break the first line (the secret read, when one is supplied). Strip it before bash reads it.
    $wslArgs += @('--exec', 'bash', '-c', 'sed ''1s/^\xEF\xBB\xBF//'' | bash -s')
    $payloadArgs = @{ Script = $Script }
    if ($PSBoundParameters.ContainsKey('SecretLine')) { $payloadArgs.SecretLine = $SecretLine }
    Format-WslStdinPayload @payloadArgs | & wsl.exe @wslArgs
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
