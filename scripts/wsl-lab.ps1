param(
    [ValidateSet('Create', 'Reset', 'Verify', 'FinishSetup')]
    [string]$Action = 'Verify'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'wsl-common.ps1')
$Distro = 'Ubuntu-Nix-Test'
$Marker = 'Ubuntu-Nix-Test blank baseline v2'
$LabRoot = Join-Path $env:USERPROFILE 'WSL\nix-lab'
$InstallPath = Join-Path $LabRoot $Distro
$Baseline = Join-Path $LabRoot 'ubuntu-26.04-blank.tar'
$BaselineHash = "$Baseline.sha256"
$Release = '26.04.1'
$ImageName = 'ubuntu-26.04.1-wsl-amd64.wsl'
$Image = Join-Path $LabRoot $ImageName
$BaseUrl = "https://releases.ubuntu.com/$Release"

function Test-Lab {
    $check = @'
set -eu
. /etc/os-release
printf 'OS: %s\nUser: %s\n' "$PRETTY_NAME" "$(whoami)"
test "$ID" = ubuntu
test "$VERSION_ID" = 26.04
test "$(whoami)" = gary
grep -Fxq 'Ubuntu-Nix-Test blank baseline v2' /etc/nix-lab-baseline
test ! -e /home/gary/reset-probe
test "$(ps -p 1 -o comm=)" = systemd
echo 'systemd is PID 1'
if command -v nix; then echo 'Nix is installed'; else echo 'Nix is not installed'; fi
'@
    Invoke-WslBashScript -Name $Distro -Script $check
}
function Save-Baseline {
    if ((Test-Path $Baseline) -or (Test-Path $BaselineHash)) { throw 'Baseline already exists; refusing to overwrite it.' }
    Test-Lab
    Invoke-Wsl -WslArgs @('--terminate', $Distro)
    Invoke-Wsl -WslArgs @('--export', $Distro, "$Baseline.partial")
    Move-Item "$Baseline.partial" $Baseline
    (Get-FileHash $Baseline -Algorithm SHA256).Hash | Set-Content $BaselineHash -Encoding ascii
    [ordered]@{ distro=$Distro; imageUrl="$BaseUrl/$ImageName"; imageSha256=(Get-FileHash $Image -Algorithm SHA256).Hash; baseline=$Baseline; createdUtc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content "$LabRoot\baseline.json" -Encoding UTF8
    Write-Output "Saved baseline $Baseline"
}

if ($Action -eq 'Create' -or $Action -eq 'FinishSetup') {
  if ($Action -eq 'Create') {
    if ((Get-WslDistroList) -contains $Distro) { throw "$Distro already exists; refusing to replace it." }
    if (Test-Path $InstallPath) { throw "Install path already exists: $InstallPath" }
    if ((Test-Path $Baseline) -or (Test-Path $BaselineHash)) { throw 'A baseline already exists; use Reset.' }
    $image = Get-UbuntuWslImage -Release $Release -ImageName $ImageName -CacheDir $LabRoot
    Import-WslDistro -Name $Distro -InstallPath $InstallPath -Image $image
  } else {
    if ((Test-Path $Baseline) -or !(Test-Path $Image)) { throw 'FinishSetup requires an imported image without a saved baseline.' }
    $registeredPath = Get-WslDistroBasePath -Name $Distro
    if ([string]$registeredPath.TrimEnd('\') -ne $InstallPath.TrimEnd('\')) { throw 'Test distribution is not in the expected lab directory.' }
  }
    $bootstrap = @'
set -eu
if ! id gary >/dev/null 2>&1; then useradd --create-home --shell /bin/bash --groups sudo gary; fi
printf '%s\n' 'gary ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gary-nix-lab
chmod 440 /etc/sudoers.d/gary-nix-lab
visudo -cf /etc/sudoers.d/gary-nix-lab
printf '[boot]\nsystemd=true\n[user]\ndefault=gary\n' > /etc/wsl.conf
printf '%s\n' 'Ubuntu-Nix-Test blank baseline v2' > /etc/nix-lab-baseline
'@
    Invoke-WslBashScript -Name $Distro -User root -Script $bootstrap
    Invoke-Wsl -WslArgs @('--terminate', $Distro)
    Save-Baseline
    Write-Output "Created $Distro and baseline $Baseline"
} elseif ($Action -eq 'Reset') {
    if (!(Test-Path $Baseline) -or !(Test-Path $BaselineHash)) { throw 'Verified baseline is missing.' }
    if ((Get-FileHash $Baseline -Algorithm SHA256).Hash -ne (Get-Content $BaselineHash -Raw).Trim()) { throw 'Baseline checksum mismatch.' }
    if ((Get-WslDistroList) -contains $Distro) {
        Invoke-Wsl -WslArgs @('-d', $Distro, '-u', 'root', '--cd', '/', '--exec', 'grep', '-Fxq', $Marker, '/etc/nix-lab-baseline')
        # Reset only the fixed disposable distribution after checking its marker and backup.
        Invoke-Wsl -WslArgs @('--terminate', $Distro)
        Invoke-Wsl -WslArgs @('--unregister', $Distro)
    }
    Invoke-Wsl -WslArgs @('--import', $Distro, $InstallPath, $Baseline, '--version', '2')
    Test-Lab
    Write-Output 'Reset complete. Files added after the baseline are gone.'
} else {
    Test-Lab
}
