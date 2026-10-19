<#
.SYNOPSIS
Validates a WSL distribution that dev-setup.ps1 created.
.DESCRIPTION
Checks the Windows side (WSL version, mirrored networking, registration, marker, install path),
then runs checks inside the distribution (default user, systemd, sudo, wsl.conf, networking mode,
clone, Nix daemon, Home Manager profile) and finally the shared environment checks.
Prints one PASS or FAIL line per check and exits non-zero if any check failed.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$Distro = 'Ubuntu'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'scripts\wsl-common.ps1')

$script:Failed = 0
function Write-Check {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][bool]$Ok, [string]$Detail = '')
    if ($Ok) { Write-Output "PASS: $Name" } else { $script:Failed++; Write-Output "FAIL: $Name $Detail".TrimEnd() }
}

$InsideScript = @'
set -u
user=__USER__
failed=0
check() { name=$1; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $name"; else echo "FAIL: $name"; failed=$((failed+1)); fi; }
{
check "default user is $user" test "$(whoami)" = "$user"
check "systemd is PID 1" test "$(ps -p 1 -o comm=)" = systemd
check "sudo works without a password" sudo -n true
check "/etc/wsl.conf sets default=$user" grep -Fxq "default=$user" /etc/wsl.conf
check "/etc/wsl.conf sets systemd=true" grep -Fxq "systemd=true" /etc/wsl.conf
check "networking mode is mirrored" test "$(wslinfo --networking-mode 2>/dev/null)" = mirrored
check "nix-config clone at ~/nix-config" test -d "$HOME/nix-config/.git"
check "nix installed in the system profile" test -x /nix/var/nix/profiles/default/bin/nix
check "nix-daemon socket is active" systemctl is-active --quiet nix-daemon.socket
check "Home Manager zsh at ~/.nix-profile/bin/zsh" test -x "$HOME/.nix-profile/bin/zsh"
check "generated profile in ~/.config/shared-dev" test -d "${XDG_CONFIG_HOME:-$HOME/.config}/shared-dev"
echo "INFO: login shell is $(getent passwd "$user" | cut -d: -f7)"
echo "Running scripts/check-shared.sh"
if bash "$HOME/nix-config/scripts/check-shared.sh"; then echo "PASS: shared environment checks"; else echo "FAIL: shared environment checks"; failed=$((failed+1)); fi
} </dev/null
echo "$failed check(s) failed inside $(hostname)"
exit "$failed"
'@

$wslVersion = Get-WslVersion
Write-Check 'WSL 2.0.0 or newer' ($wslVersion -and $wslVersion -ge [version]'2.0.0') "(found '$wslVersion')"

$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
$mode = $null
if (Test-Path -LiteralPath $wslConfig) { $mode = Get-WslConfigNetworkingMode -Lines ([IO.File]::ReadAllLines($wslConfig)) }
Write-Check '.wslconfig sets networkingMode=mirrored' ($mode -ieq 'mirrored') "(found '$mode')"

$registered = (Get-WslDistroList) -contains $Distro
Write-Check "'$Distro' is registered" $registered
$user = $null
if ($registered) {
    $user = Get-DevSetupUser -Name $Distro
    Write-Check 'dev-setup marker names the user' ([bool]$user) '(/etc/dev-setup-distro missing; not created by dev-setup?)'
    $expected = Join-Path $env:LOCALAPPDATA "WSL\$Distro"
    $actual = Get-WslDistroBasePath -Name $Distro
    Write-Check "installed at $expected" ([bool]$actual -and ($actual.TrimEnd('\') -ieq $expected.TrimEnd('\'))) "(found '$actual')"
}
if ($user) {
    try {
        Invoke-WslBashScript -Name $Distro -Script $InsideScript.Replace('__USER__', $user)
    } catch {
        $script:Failed++
        Write-Output "FAIL: checks inside '$Distro' ($_)"
    }
} else {
    $script:Failed++
    Write-Output "FAIL: skipped checks inside '$Distro'"
}

if ($script:Failed -gt 0) { throw "$script:Failed check(s) failed for '$Distro'." }
Write-Output "All checks passed for '$Distro'."
