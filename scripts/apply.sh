#!/usr/bin/env bash
# shellcheck source=scripts/common.sh
source "$(dirname -- "$0")/common.sh"
test -f "$CONFIG_ROOT/flake.lock"
cd "$CONFIG_ROOT"
nix build --no-update-lock-file "path:$CONFIG_ROOT#homeConfigurations.gary.activationPackage" -o result
# Back up stock Ubuntu dotfiles on first activation; never silently overwrite them.
HOME_MANAGER_BACKUP_EXT=before-nix ./result/activate
shell_path=/home/gary/.nix-profile/bin/zsh
test -x "$shell_path"
if ! grep -Fxq "$shell_path" /etc/shells; then
  printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
fi
if [[ $(getent passwd gary | cut -d: -f7) != "$shell_path" ]]; then
  sudo usermod --shell "$shell_path" gary
fi
printf 'Applied %s\n' "$(readlink -f result)"
