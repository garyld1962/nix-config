#!/usr/bin/env bash
# shellcheck source=scripts/shared-common.sh
source "$(dirname -- "$0")/shared-common.sh"
shell_path=$DEV_HOME/.nix-profile/bin/zsh
test -x "$shell_path"
# The child Zsh expands its positional argument.
# Fake Windows entries exercise the PATH filter in home/shell.zsh; only VS Code may survive.
windows_path='/mnt/c/Windows/system32:/mnt/c/Users/x/AppData/Local/Programs/Microsoft VS Code/bin:/mnt/c/Program Files/Docker/Docker/resources/bin'
# shellcheck disable=SC2016
env -i HOME="$DEV_HOME" USER="$DEV_USER" LOGNAME="$DEV_USER" TERM=xterm-256color \
  PATH="/usr/bin:/bin:$windows_path" WSL_DISTRO_NAME="$WSL_DISTRO_NAME" CONFIG_ROOT="$CONFIG_ROOT" \
  timeout --kill-after=5 90 "$shell_path" -lic 'source "$1"' zsh "$CONFIG_ROOT/scripts/check-session.zsh"
# shellcheck disable=SC2016
env -i HOME="$DEV_HOME" USER="$DEV_USER" LOGNAME="$DEV_USER" TERM=xterm-256color \
  PATH=/usr/bin:/bin WSL_DISTRO_NAME="$WSL_DISTRO_NAME" \
  "$shell_path" -lc 'python3 "$1"' zsh "$CONFIG_ROOT/scripts/check-herdr.py"
nix develop --no-update-lock-file "$CONFIG_ROOT" --command \
  node -e 'if (process.versions.node.split(".")[0] !== "22") process.exit(1); console.log("PASS: project development shell uses Node 22")'
