#!/usr/bin/env bash
# shellcheck source=scripts/common.sh
source "$(dirname -- "$0")/common.sh"
# The child Zsh expands its positional argument.
# shellcheck disable=SC2016
env -i HOME=/home/gary USER=gary LOGNAME=gary TERM=xterm-256color \
  PATH=/usr/bin:/bin WSL_DISTRO_NAME=Ubuntu-Nix-Test \
  /home/gary/.nix-profile/bin/zsh -lic 'source "$1"' zsh "$CONFIG_ROOT/scripts/check-session.zsh"
# The child Zsh expands its positional argument.
# shellcheck disable=SC2016
env -i HOME=/home/gary USER=gary LOGNAME=gary TERM=xterm-256color \
  PATH=/usr/bin:/bin WSL_DISTRO_NAME=Ubuntu-Nix-Test \
  /home/gary/.nix-profile/bin/zsh -lc 'python3 "$1"' zsh "$CONFIG_ROOT/scripts/check-herdr.py"
nix develop --no-update-lock-file "path:$CONFIG_ROOT" --command \
  node -e 'if (process.versions.node.split(".")[0] !== "22") process.exit(1); console.log("PASS: project development shell uses Node 22")'
