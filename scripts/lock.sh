#!/usr/bin/env bash
# shellcheck source=scripts/common.sh
source "$(dirname -- "$0")/common.sh"
cd "$CONFIG_ROOT"
nix flake lock "path:$CONFIG_ROOT"
