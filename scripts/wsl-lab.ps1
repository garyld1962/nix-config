param(
    [ValidateSet('Create', 'Reset', 'Verify', 'FinishSetup')]
    [string]$Action = 'Verify'
)
$ErrorActionPreference = 'Stop'
$Distro = 'Ubuntu-Nix-Test'
$LabRoot = Join-Path $env:USERPROFILE 'WSL\nix-lab'
$InstallPath = Join-Path $LabRoot $Distro
$Baseline = Join-Path $LabRoot 'ubuntu-24.04-blank.tar'
$BaselineHash = "$Baseline.sha256"
$ImageName = 'ubuntu-24.04.5-wsl-amd64.wsl'
$Image = Join-Path $LabRoot $ImageName
$BaseUrl = 'https://releases.ubuntu.com/24.04.5'

function Invoke-Wsl {
    param([string[]]$WslArgs)
    & wsl.exe @WslArgs
    if ($LASTEXITCODE -ne 0) { throw "WSL failed: $($WslArgs -join ' ')" }
}
function Get-Distros {
    $result = & wsl.exe --list --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read WSL distributions.' }
    @($result | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
}
function Verify-Lab {
    $check = @'
set -eu
. /etc/os-release
printf 'OS: %s\nUser: %s\n' "$PRETTY_NAME" "$(whoami)"
test "$ID" = ubuntu
test "$VERSION_ID" = 24.04
test "$(whoami)" = gary
grep -Fxq 'Ubuntu-Nix-Test blank baseline v1' /etc/nix-lab-baseline
test ! -e /home/gary/reset-probe
test "$(ps -p 1 -o comm=)" = systemd
echo 'systemd is PID 1'
if command -v nix; then echo 'Nix is installed'; else echo 'Nix is not installed'; fi
'@
    ($check + "`nexit `$?`n") | & wsl.exe -d $Distro --cd / --exec bash -s
    if ($LASTEXITCODE -ne 0) { throw 'Lab verification failed.' }
}
function Save-Baseline {
    if ((Test-Path $Baseline) -or (Test-Path $BaselineHash)) { throw 'Baseline already exists; refusing to overwrite it.' }
    Verify-Lab
    Invoke-Wsl -WslArgs @('--terminate', $Distro)
    Invoke-Wsl -WslArgs @('--export', $Distro, "$Baseline.partial")
    Move-Item "$Baseline.partial" $Baseline
    (Get-FileHash $Baseline -Algorithm SHA256).Hash | Set-Content $BaselineHash -Encoding ascii
    [ordered]@{ distro=$Distro; imageUrl="$BaseUrl/$ImageName"; imageSha256=(Get-FileHash $Image -Algorithm SHA256).Hash; baseline=$Baseline; createdUtc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content "$LabRoot\baseline.json" -Encoding UTF8
    Write-Output "Saved baseline $Baseline"
}

if ($Action -eq 'Create' -or $Action -eq 'FinishSetup') {
  if ($Action -eq 'Create') {
    if ((Get-Distros) -contains $Distro) { throw "$Distro already exists; refusing to replace it." }
    if (Test-Path $InstallPath) { throw "Install path already exists: $InstallPath" }
    if ((Test-Path $Baseline) -or (Test-Path $BaselineHash)) { throw 'A baseline already exists; use Reset.' }
    New-Item -ItemType Directory -Force -Path $LabRoot | Out-Null
    & curl.exe --fail --location --retry 3 --output "$LabRoot\SHA256SUMS" "$BaseUrl/SHA256SUMS"
    if ($LASTEXITCODE -ne 0) { throw 'Checksum download failed.' }
    $entry = @(Get-Content "$LabRoot\SHA256SUMS" | Where-Object { $_ -match "^[a-fA-F0-9]{64}\s+\*?$([regex]::Escape($ImageName))$" })
    if ($entry.Count -ne 1) { throw 'Expected exactly one published image checksum.' }
    $expected = ($entry[0] -split '\s+')[0]
    if (!(Test-Path $Image)) {
        & curl.exe --fail --location --retry 3 --output "$Image.partial" "$BaseUrl/$ImageName"
        if ($LASTEXITCODE -ne 0) { throw 'Image download failed.' }
        Move-Item "$Image.partial" $Image
    }
    if ((Get-FileHash $Image -Algorithm SHA256).Hash -ne $expected) { throw 'Image checksum mismatch.' }
    Invoke-Wsl -WslArgs @('--import', $Distro, $InstallPath, $Image, '--version', '2')
  } else {
    if ((Test-Path $Baseline) -or !(Test-Path $Image)) { throw 'FinishSetup requires an imported image without a saved baseline.' }
    $registeredPath = Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | Get-ItemProperty | Where-Object { $_.DistributionName -eq $Distro } | Select-Object -ExpandProperty BasePath
    if ($registeredPath.TrimEnd('\') -ne $InstallPath.TrimEnd('\')) { throw 'Test distribution is not in the expected lab directory.' }
  }
    $bootstrap = @'
set -eu
if ! id gary >/dev/null 2>&1; then useradd --create-home --shell /bin/bash --groups sudo gary; fi
printf '%s\n' 'gary ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gary-nix-lab
chmod 440 /etc/sudoers.d/gary-nix-lab
visudo -cf /etc/sudoers.d/gary-nix-lab
printf '[boot]\nsystemd=true\n[user]\ndefault=gary\n' > /etc/wsl.conf
printf '%s\n' 'Ubuntu-Nix-Test blank baseline v1' > /etc/nix-lab-baseline
'@
    ($bootstrap + "`nexit `$?`n") | & wsl.exe -d $Distro -u root --cd / --exec bash -s
    if ($LASTEXITCODE -ne 0) { throw 'Minimal user setup failed.' }
    Invoke-Wsl -WslArgs @('--terminate', $Distro)
    Save-Baseline
    Write-Output "Created $Distro and baseline $Baseline"
} elseif ($Action -eq 'Reset') {
    if (!(Test-Path $Baseline) -or !(Test-Path $BaselineHash)) { throw 'Verified baseline is missing.' }
    if ((Get-FileHash $Baseline -Algorithm SHA256).Hash -ne (Get-Content $BaselineHash -Raw).Trim()) { throw 'Baseline checksum mismatch.' }
    if ((Get-Distros) -contains $Distro) {
        Invoke-Wsl -WslArgs @('-d', $Distro, '-u', 'root', '--cd', '/', '--exec', 'grep', '-Fxq', 'Ubuntu-Nix-Test blank baseline v1', '/etc/nix-lab-baseline')
        # Reset only the fixed disposable distribution after checking its marker and backup.
        Invoke-Wsl -WslArgs @('--terminate', $Distro)
        Invoke-Wsl -WslArgs @('--unregister', $Distro)
    }
    Invoke-Wsl -WslArgs @('--import', $Distro, $InstallPath, $Baseline, '--version', '2')
    Verify-Lab
    Write-Output 'Reset complete. Files added after the baseline are gone.'
} else {
    Verify-Lab
}
