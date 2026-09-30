#!/usr/bin/env bash
# shellcheck source=scripts/common.sh
source "$(dirname -- "$0")/common.sh"
if [[ ! -x /nix/var/nix/profiles/default/bin/nix ]]; then
  installer=$(mktemp)
  trap 'rm -f -- "$installer"' EXIT
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    https://releases.nixos.org/nix/nix-2.35.2/install -o "$installer"
  printf '%s  %s\n' 9adda97297d9e8ab360df95c729eabff4f4f93d6db091953c3a68f29e3fb130c "$installer" | sha256sum -c -
  sh "$installer" --daemon --yes --no-channel-add --no-modify-profile
fi
sudo systemctl enable --now nix-daemon.socket
/nix/var/nix/profiles/default/bin/nix --version
