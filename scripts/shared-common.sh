#!/usr/bin/env bash
set -euo pipefail
CONFIG_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export CONFIG_ROOT

if [[ -z ${WSL_DISTRO_NAME:-} ]] || [[ ! -r /etc/os-release ]]; then
  printf '%s\n' 'Run this installer inside an Ubuntu WSL distribution.' >&2
  exit 1
fi
# Ubuntu supplies this file; it is not user input.
# shellcheck source=/dev/null
source /etc/os-release
if [[ ${ID:-} != ubuntu || $(uname -m) != x86_64 ]]; then
  printf '%s\n' 'The shared environment currently supports x86-64 Ubuntu WSL.' >&2
  exit 1
fi
if [[ $(id -u) == 0 ]]; then
  printf '%s\n' 'Run as your normal developer account, not root or sudo bash.' >&2
  exit 1
fi
DEV_USER=$(id -un)
DEV_HOME=$(getent passwd "$DEV_USER" | cut -d: -f6)
if [[ -z $DEV_HOME || $DEV_HOME != /* || $HOME != "$DEV_HOME" ]]; then
  printf '%s\n' 'HOME must match the current account home directory.' >&2
  exit 1
fi
export DEV_USER DEV_HOME
if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  set +u
  # shellcheck source=/dev/null
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -u
fi
export NIX_CONFIG="${NIX_CONFIG:-}
experimental-features = nix-command flakes"
