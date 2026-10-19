#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Usage: bash bootstrap.sh [--no-change-shell]' \
    'Install Nix and the shared development environment for the current Ubuntu WSL user.' \
    'Personal setup is separate. Use --no-change-shell to keep your current login shell.'
  exit 0
fi
if (( $# > 1 )) || { (( $# == 1 )) && [[ $1 != --no-change-shell ]]; }; then
  printf '%s\n' 'Usage: bash bootstrap.sh [--no-change-shell]' >&2
  exit 64
fi
bash "$root/scripts/install-nix.sh"
bash "$root/scripts/apply-shared.sh" "$@"
