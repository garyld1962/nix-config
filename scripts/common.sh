#!/usr/bin/env bash
set -euo pipefail
if [[ ${WSL_DISTRO_NAME:-} != Ubuntu-Nix-Test ]] ||
   ! grep -Fxq 'Ubuntu-Nix-Test blank baseline v1' /etc/nix-lab-baseline; then
  echo 'This script only operates inside Ubuntu-Nix-Test.' >&2
  exit 1
fi
if [[ $(id -un) != gary ]]; then
  echo 'Run this script as gary.' >&2
  exit 1
fi
CONFIG_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export CONFIG_ROOT
if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
  # The Nix script checks optional environment variables.
  set +u
  # shellcheck source=/dev/null
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -u
fi
export NIX_CONFIG='experimental-features = nix-command flakes'
