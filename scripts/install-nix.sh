#!/usr/bin/env bash
# shellcheck source=scripts/shared-common.sh
source "$(dirname -- "$0")/shared-common.sh"
if [[ $(ps -p 1 -o comm=) != systemd ]]; then
  printf '%s\n' 'Enable systemd in /etc/wsl.conf ([boot] systemd=true), then restart WSL from Windows.' >&2
  exit 1
fi
command -v sudo >/dev/null || { printf '%s\n' 'Your Ubuntu account needs sudo.' >&2; exit 1; }
# Validate permission for an actual command. `sudo -v` can still ask for a
# password when an account has both password and NOPASSWD rules.
sudo true
missing=()
for command_name in curl git python3 xz; do
  command -v "$command_name" >/dev/null || missing+=("$command_name")
done
[[ -r /etc/ssl/certs/ca-certificates.crt ]] || missing+=(ca-certificates)
if (( ${#missing[@]} )); then
  # xz is supplied by the xz-utils Ubuntu package.
  packages=(curl git python3 xz-utils ca-certificates)
  sudo apt-get update
  sudo apt-get install -y "${packages[@]}"
fi
if ! command -v nix >/dev/null; then
  if [[ -e /nix ]]; then
    printf '%s\n' 'An existing /nix directory was found without a usable Nix command. Repair that installation first.' >&2
    exit 1
  fi
  installer=$(mktemp)
  trap 'rm -f -- "$installer"' EXIT
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    https://releases.nixos.org/nix/nix-2.35.2/install -o "$installer"
  printf '%s  %s\n' 9adda97297d9e8ab360df95c729eabff4f4f93d6db091953c3a68f29e3fb130c "$installer" | sha256sum -c -
  sh "$installer" --daemon --yes --no-channel-add --no-modify-profile
fi
sudo systemctl enable --now nix-daemon.socket
printf '%s\n' 'Nix is ready. Existing installations retain their installed Nix version.'
