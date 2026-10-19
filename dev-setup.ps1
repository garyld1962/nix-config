<#
.SYNOPSIS
One-command Ubuntu WSL developer bootstrap.
.DESCRIPTION
Run from a normal (not elevated) PowerShell window:
  irm https://raw.githubusercontent.com/garyld1962/nix-config/main/dev-setup.ps1 | iex
Prompts for a Linux username and password, enables WSL 2 with mirrored networking,
imports Ubuntu 26.04.1 from a checksum-verified image, and runs bootstrap.sh inside it.
Rerunning after a failure resumes without creating a second distribution.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$Distro = 'Ubuntu',
    [string]$Repo = 'https://github.com/garyld1962/nix-config.git',
    [string]$Branch = 'main',
    [switch]$NoChangeShell
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$ImageRelease = '26.04.1'
$ImageName = 'ubuntu-26.04.1-wsl-amd64.wsl'
$InstallPath = Join-Path $env:LOCALAPPDATA "WSL\$Distro"
$ImageCache = Join-Path $env:LOCALAPPDATA 'WSL\images'
$WslConfig = Join-Path $env:USERPROFILE '.wslconfig'

# Load shared functions: the sibling file when run from a clone, otherwise the same branch on GitHub.
$rawBase = ($Repo -replace '^https://github\.com/([^/]+/[^/]+?)(\.git)?/?$', 'https://raw.githubusercontent.com/$1') + "/$Branch"
$common = ''
if ($PSScriptRoot) { $common = Join-Path $PSScriptRoot 'scripts\wsl-common.ps1' }
if (-not ($common -and (Test-Path -LiteralPath $common))) {
    $fetchDir = Join-Path ([IO.Path]::GetTempPath()) "dev-setup-$PID"
    New-Item -ItemType Directory -Force -Path $fetchDir | Out-Null
    $common = Join-Path $fetchDir 'wsl-common.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri "$rawBase/scripts/wsl-common.ps1" -OutFile $common
}
. $common

function ConvertTo-PlainText {
    param([Parameter(Mandatory)][securestring]$Secure)
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$RootScript = @'
set -eu
user=__USER__
{
if ! id "$user" >/dev/null 2>&1; then useradd --create-home --shell /bin/bash --groups sudo "$user"; fi
printf '%s:%s\n' "$user" "$SECRET" | chpasswd
unset SECRET
printf '%s\n' "$user ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$user-dev-setup"
chmod 440 "/etc/sudoers.d/$user-dev-setup"
visudo -cf "/etc/sudoers.d/$user-dev-setup"
printf '[boot]\nsystemd=true\n[user]\ndefault=%s\n' "$user" > /etc/wsl.conf
printf 'dev-setup v1 %s\n' "$user" > /etc/dev-setup-distro
} </dev/null
'@

$BootstrapScript = @'
set -eu
{
sudo apt-get update
sudo apt-get install -y git
if [ -d nix-config/.git ]; then git -C nix-config pull --ff-only; else git clone --branch "__BRANCH__" "__REPO__" nix-config; fi
cd nix-config
bash bootstrap.sh __ARGS__
} </dev/null
'@

# Stage 0: guards. Nothing below changes the machine until the user confirms.
if (Test-Elevated) { throw 'Run dev-setup from a normal (not elevated) PowerShell window. WSL distributions belong to the signed-in user.' }
$build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
if ($build -lt 19041) { throw "WSL 2 needs Windows 10 build 19041 or newer; this is build $build." }
if ($build -lt 22621) { throw "Mirrored networking needs Windows 11 22H2 (build 22621) or newer; this is build $build." }
$wslInstalled = Test-WslInstalled
$existingUser = $null
if ($wslInstalled -and ((Get-WslDistroList) -contains $Distro)) {
    $existingUser = Get-DevSetupUser -Name $Distro
    if (-not $existingUser) {
        throw "'$Distro' already exists but was not created by dev-setup. Pick another name with -Distro, or remove it with: wsl --unregister $Distro"
    }
}

# Stage 1: prompts and confirmation.
$user = $existingUser
$password = $null
if (-not $existingUser) {
    do {
        $user = (Read-Host 'Linux username (lowercase letters, digits, - and _; max 32)').Trim()
        if (-not (Test-UbuntuUsername $user)) { Write-Output "Invalid username '$user'." }
    } until (Test-UbuntuUsername $user)
    do {
        $first = ConvertTo-PlainText (Read-Host 'Password' -AsSecureString)
        $second = ConvertTo-PlainText (Read-Host 'Confirm password' -AsSecureString)
        if (-not $first) { Write-Output 'The password cannot be empty.' }
        elseif ($first -cne $second) { Write-Output 'The passwords do not match.' }
    } until ($first -and ($first -ceq $second))
    $password = $first
    $first = $null
    $second = $null
}
Write-Output '', 'dev-setup will set up:',
    "  Distribution:  $Distro",
    "  Install path:  $InstallPath",
    "  Username:      $user",
    "  Image:         $ImageName (Ubuntu $ImageRelease)",
    '  Networking:    mirrored (.wslconfig; WSL restarts if this changes)',
    "  Repository:    $Repo ($Branch)"
if ($existingUser) { Write-Output '  Existing distribution: resuming at the bootstrap stage.' }
if ((Read-Host 'Proceed? [y/N]') -notmatch '^(y|yes)$') { Write-Output 'No changes made.'; return }

# Stage 2: Windows prerequisites.
if (-not $wslInstalled) {
    Invoke-Wsl -WslArgs @('--install', '--no-distribution')
    Write-Output 'Reboot, then run the same command again.'
    return
}
& wsl.exe --update
if ($LASTEXITCODE -ne 0) { Write-Warning 'wsl --update failed (Microsoft Store unreachable?). Continuing with the installed version.' }
$wslVersion = Get-WslVersion
if (-not $wslVersion -or $wslVersion -lt [version]'2.0.0') { throw "WSL 2.0.0 or newer is required (found '$wslVersion'). Run 'wsl --update' and retry." }
if (Merge-WslConfigMirrored -Path $WslConfig) {
    Write-Output 'Enabled mirrored networking in .wslconfig; restarting WSL.'
    Invoke-Wsl -WslArgs @('--shutdown')
}

# Stage 3: distribution and user. Skipped on resume.
if (-not $existingUser) {
    $image = Get-UbuntuWslImage -Release $ImageRelease -ImageName $ImageName -CacheDir $ImageCache
    Write-Output "Importing $Distro into $InstallPath"
    Import-WslDistro -Name $Distro -InstallPath $InstallPath -Image $image
    Invoke-WslBashScript -Name $Distro -User root -SecretLine $password -Script $RootScript.Replace('__USER__', $user)
    $password = $null
    Invoke-Wsl -WslArgs @('--terminate', $Distro)
}

# Stage 4: clone and bootstrap as the developer.
$bootstrapArgs = ''
if ($NoChangeShell) { $bootstrapArgs = '--no-change-shell' }
Invoke-WslBashScript -Name $Distro -Script $BootstrapScript.Replace('__BRANCH__', $Branch).Replace('__REPO__', $Repo).Replace('__ARGS__', $bootstrapArgs)
Write-Output '', "Done. Open '$Distro' from the Start menu, or run: wsl -d $Distro"
