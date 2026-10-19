#!/usr/bin/env bash
# shellcheck source=scripts/common.sh
source "$(dirname -- "$0")/common.sh"
bash "$CONFIG_ROOT/scripts/check-shared.sh"
