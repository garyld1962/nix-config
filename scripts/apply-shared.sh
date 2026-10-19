#!/usr/bin/env bash
# shellcheck source=scripts/shared-common.sh
source "$(dirname -- "$0")/shared-common.sh"
change_shell=true
if [[ ${1:-} == --no-change-shell ]]; then
  change_shell=false
elif (( $# )); then
  printf '%s\n' 'Usage: bash scripts/apply-shared.sh [--no-change-shell]' >&2
  exit 64
fi
(( $# <= 1 )) || { printf '%s\n' 'Too many arguments.' >&2; exit 64; }
command -v nix >/dev/null || { printf '%s\n' 'Run bash bootstrap.sh to install Nix first.' >&2; exit 1; }
profile_dir=${XDG_CONFIG_HOME:-$DEV_HOME/.config}/shared-dev
[[ $profile_dir == /* ]] || { printf '%s\n' 'XDG_CONFIG_HOME must be an absolute path.' >&2; exit 1; }
python3 "$CONFIG_ROOT/scripts/generate-profile.py" --root "$CONFIG_ROOT" \
  --destination "$profile_dir" --username "$DEV_USER" --home "$DEV_HOME"
# Refresh only the local shared source. Its checked-in lock file pins dependencies.
nix flake update shared-dev --flake "$profile_dir"
nix build --no-update-lock-file "$profile_dir#homeConfigurations.default.activationPackage" \
  --out-link "$profile_dir/result"
HOME_MANAGER_BACKUP_EXT=before-shared-dev "$profile_dir/result/activate"
shell_path=$DEV_HOME/.nix-profile/bin/zsh
if $change_shell; then
  test -x "$shell_path"
  if ! grep -Fxq "$shell_path" /etc/shells; then
    printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null
  fi
  if [[ $(getent passwd "$DEV_USER" | cut -d: -f7) != "$shell_path" ]]; then
    sudo usermod --shell "$shell_path" "$DEV_USER"
  fi
fi
printf 'Applied %s\nOpen a new terminal to use the shared environment.\n' "$(readlink -f "$profile_dir/result")"
