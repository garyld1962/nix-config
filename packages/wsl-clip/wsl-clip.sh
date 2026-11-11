# shellcheck shell=bash
# pbcopy / pbpaste for WSL. Uses wl-clipboard against the WSLg Wayland socket,
# which WSLg keeps in sync with the Windows clipboard, so UTF-8 survives.
# (clip.exe converts through the OEM code page and mangles non-ASCII text.)
# SSH sessions have no WAYLAND_DISPLAY, so the WSLg socket is used directly
# whenever it exists. Elsewhere any Wayland session works.

mode=$(basename "$0")
case $mode in
  pbcopy) tool=wl-copy; set -- "$@" ;;
  pbpaste) tool=wl-paste; set -- --no-newline "$@" ;;
  *) echo "wsl-clip: run as pbcopy or pbpaste, not $mode" >&2; exit 64 ;;
esac

wslg_socket=/mnt/wslg/runtime-dir/wayland-0
if [ -S "$wslg_socket" ]; then
  export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir WAYLAND_DISPLAY=wayland-0
elif [ -z "${WAYLAND_DISPLAY:-}" ]; then
  echo "$mode: no Wayland clipboard available (WSLg socket missing and WAYLAND_DISPLAY unset)" >&2
  exit 69
fi

# WSL_CLIP_DRY_RUN=1 prints the command instead, so checks can run headless.
if [ -n "${WSL_CLIP_DRY_RUN:-}" ]; then
  printf '%s %s\n' "$tool" "$*" | sed 's/ $//'
  exit 0
fi
exec "$tool" "$@"
