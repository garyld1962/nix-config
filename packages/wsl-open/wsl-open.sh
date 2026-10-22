# shellcheck shell=bash
# Open a URL or file with the Windows default handler when running under WSL.
# Falls back to the system xdg-open elsewhere. Also installed as `xdg-open`
# and `open`, so tools that honour BROWSER or call xdg-open just work.

usage() {
  echo 'Usage: wsl-open <url-or-path>' >&2
  exit 64
}

[ "$#" -eq 1 ] || usage
target=$1

is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]
}

if ! is_wsl; then
  for fallback in /usr/bin/xdg-open /usr/bin/sensible-browser; do
    [ -x "$fallback" ] && exec "$fallback" "$target"
  done
  echo 'wsl-open: not running under WSL and no xdg-open found' >&2
  exit 69
fi

case $target in
  *://*|mailto:*)
    ;;
  *)
    if [ -e "$target" ]; then
      target=$(wslpath -w "$(realpath "$target")")
    fi
    ;;
esac

# rundll32 is fast and uses the per-user default app for the URL scheme or
# file type. Run it from a Windows-visible directory to avoid UNC warnings.
# WSL_OPEN_DRY_RUN=1 prints the command instead, so checks can run headless.
if [ -n "${WSL_OPEN_DRY_RUN:-}" ]; then
  printf '%s\n' "rundll32.exe url.dll,FileProtocolHandler $target"
  exit 0
fi
cd /mnt/c 2>/dev/null || true
exec /mnt/c/Windows/System32/rundll32.exe url.dll,FileProtocolHandler "$target"
