#!/usr/bin/env bash
# Personal post-install for an Ubuntu WSL account that bootstrap.sh already set up.
# Run as your normal user after the shared bootstrap:  bash post-install.sh
# Safe to rerun: every step is idempotent and only updates what is missing or stale.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ${1:-} == --help ]]; then
  printf '%s\n' 'Usage: bash post-install.sh' \
    'Personal setup after the shared bootstrap:' \
    '  - prompt for your Git name and email (~/.config/git/personal.inc)' \
    '  - sign in to GitHub with gh (skipped when already signed in)' \
    '  - enable the optional toolchains module (Go, .NET SDK, rustup, TypeScript) and reapply the profile' \
    '  - install the Rust stable toolchain through rustup' \
    '  - install Claude Code, Codex, and Copilot CLI under ~/.local' \
    '  - offer to enable Docker Desktop WSL integration for this distribution' \
    '  - connect VS Code on Windows to this distribution (Remote - WSL)'
  exit 0
fi
(( $# == 0 )) || { printf '%s\n' 'Usage: bash post-install.sh' >&2; exit 64; }
[[ $EUID -ne 0 ]] || { printf '%s\n' 'Run as your normal user, not with sudo.' >&2; exit 1; }
command -v nix >/dev/null || { printf '%s\n' 'Run bash bootstrap.sh first.' >&2; exit 1; }

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
interactive=false
[[ -t 0 && -t 1 ]] && interactive=true

config_home=${XDG_CONFIG_HOME:-$HOME/.config}
mkdir -p "$HOME/.local/bin" "$config_home/git" "$config_home/shared-dev"

# ---------------------------------------------------------------------------
step 'Git identity (~/.config/git/personal.inc)'
personal_inc=$config_home/git/personal.inc
current_name=$(git config --file "$personal_inc" --get user.name 2>/dev/null || true)
current_email=$(git config --file "$personal_inc" --get user.email 2>/dev/null || true)
if $interactive; then
  read -r -p "Full name [${current_name:-required}]: " name
  name=${name:-$current_name}
  while [[ -z $name ]]; do read -r -p 'Full name: ' name; done
  read -r -p "Email [${current_email:-required}]: " email
  email=${email:-$current_email}
  while [[ $email != *@* ]]; do read -r -p 'Email (must contain @): ' email; done
  git config --file "$personal_inc" user.name "$name"
  git config --file "$personal_inc" user.email "$email"
  printf 'Git identity: %s <%s>\n' "$name" "$email"
elif [[ -n $current_name && -n $current_email ]]; then
  printf 'Keeping existing identity: %s <%s>\n' "$current_name" "$current_email"
else
  warn 'No terminal; skipped the Git identity prompt. Rerun interactively to set it.'
fi

# ---------------------------------------------------------------------------
step 'GitHub CLI sign-in'
if gh auth status >/dev/null 2>&1; then
  gh auth status 2>&1 | head -2
elif $interactive; then
  gh auth login
else
  warn 'No terminal; skipped gh auth login.'
fi

# ---------------------------------------------------------------------------
step 'Shared profile: enable the toolchains module and reapply'
modules_file=$config_home/shared-dev/modules
grep -Fxq toolchains "$modules_file" 2>/dev/null || printf 'toolchains\n' >>"$modules_file"
bash "$root/scripts/apply-shared.sh"
# Make the freshly activated profile visible to the rest of this script.
export PATH=$HOME/.nix-profile/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH
# An earlier post-install wrote a PATH block into local.zsh; the module replaces it.
local_zsh=$config_home/zsh/local.zsh
if [[ -f $local_zsh ]] && grep -Fq '# >>> post-install' "$local_zsh"; then
  tmp=$(mktemp)
  awk '/^# >>> post-install/{skip=1} !skip{print} /^# <<< post-install/{skip=0}' "$local_zsh" >"$tmp"
  if [[ -s $tmp ]]; then mv "$tmp" "$local_zsh"; else rm -f "$tmp" "$local_zsh"; fi
  printf 'Removed the obsolete PATH block from %s\n' "$local_zsh"
fi

# ---------------------------------------------------------------------------
step 'Rust toolchain (rustup stable)'
if rustup show active-toolchain >/dev/null 2>&1; then
  rustup update --no-self-update stable
else
  rustup default stable
fi

# ---------------------------------------------------------------------------
step 'npm globals: Codex, Copilot CLI'
# Node comes from the Nix store, which is read-only, so global installs go to ~/.local.
npm config set prefix "$HOME/.local"
npm install -g @openai/codex @github/copilot

# ---------------------------------------------------------------------------
step 'Claude Code'
if [[ -x $HOME/.local/bin/claude ]]; then
  "$HOME/.local/bin/claude" update || warn 'claude update failed; the installed version is kept.'
else
  curl -fsSL https://claude.ai/install.sh | bash
fi

# ---------------------------------------------------------------------------
step 'Docker Desktop WSL integration'
# Docker Desktop on Windows provides the engine. With WSL integration on for this
# distribution it mounts a Linux docker client at /usr/bin/docker plus the socket;
# without it the Windows PATH only offers a stub that prints a hint.
docker_desktop_dir='/mnt/c/Program Files/Docker/Docker'
docker_exe=$docker_desktop_dir/resources/bin/docker.exe
win() { (cd /mnt/c && "$@"); } # Windows programs warn when started from a Linux directory.
docker_desktop_running() {
  win /mnt/c/Windows/System32/tasklist.exe /FI 'IMAGENAME eq Docker Desktop.exe' /NH 2>/dev/null | grep -q 'Docker Desktop.exe'
}
integration_configured() {
  python3 - "$1" "$WSL_DISTRO_NAME" <<'PY'
import json, sys
from pathlib import Path
try:
    settings = json.loads(Path(sys.argv[1]).read_text())
except (OSError, ValueError):
    sys.exit(1)
# settings-store.json uses PascalCase keys; older files and admin settings use camelCase.
found = any(sys.argv[2] in (settings.get(k) or []) for k in ("IntegratedWslDistros", "integratedWslDistros"))
sys.exit(0 if found else 1)
PY
}
enable_integration() {
  python3 - "$1" "$WSL_DISTRO_NAME" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
settings = json.loads(path.read_text()) if path.exists() else {}
keys = ("IntegratedWslDistros", "integratedWslDistros")
key = next((k for k in keys if k in settings), None)
if key is None:
    # Match the casing of the existing keys; Docker Desktop 4.3x+ stores PascalCase.
    key = keys[1] if settings and not any(k[:1].isupper() for k in settings) else keys[0]
distros = settings.get(key) or []
if sys.argv[2] not in distros:
    distros.append(sys.argv[2])
settings[key] = distros
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(settings, indent=2) + "\n")
PY
}
wait_for_docker() {
  for _ in $(seq 1 60); do
    [[ -x /usr/bin/docker ]] && return 0
    sleep 2
  done
  return 1
}
if [[ -x /usr/bin/docker ]]; then
  printf 'Enabled: %s\n' "$(/usr/bin/docker --version)"
elif [[ ! -f "$docker_desktop_dir/Docker Desktop.exe" ]]; then
  printf 'Docker Desktop is not installed on Windows; skipping (winget install Docker.DockerDesktop).\n'
else
  appdata=$(win /mnt/c/Windows/System32/cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')
  settings_file=$(wslpath -u "$appdata")/Docker/settings-store.json
  if integration_configured "$settings_file"; then
    printf 'Integration for %s is configured, but Docker Desktop is not running.\n' "$WSL_DISTRO_NAME"
    prompt='Start Docker Desktop now? [Y/n] '
    needs_enable=false
  else
    printf 'Docker Desktop is installed, but WSL integration for %s is off.\n' "$WSL_DISTRO_NAME"
    prompt='Enable it now? Docker Desktop will be started or restarted. [Y/n] '
    needs_enable=true
  fi
  if ! $interactive; then
    warn 'No terminal; rerun interactively, or use Docker Desktop: Settings > Resources > WSL integration.'
  else
    read -r -p "$prompt" answer
    if [[ ${answer:-y} =~ ^[Yy]$ ]]; then
      if $needs_enable; then
        if docker_desktop_running; then
          printf 'Stopping Docker Desktop to change its settings...\n'
          win "$docker_exe" desktop stop >/dev/null 2>&1 \
            || warn 'Could not stop Docker Desktop; if integration does not appear, quit it from the tray icon and rerun.'
        fi
        enable_integration "$settings_file"
        printf 'Added %s to the integrated WSL distros in %s\n' "$WSL_DISTRO_NAME" "$settings_file"
      fi
      printf 'Starting Docker Desktop...\n'
      if ! win "$docker_exe" desktop start >/dev/null 2>&1; then
        win /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command \
          Start-Process -FilePath "'$(wslpath -w "$docker_desktop_dir/Docker Desktop.exe")'"
      fi
      if wait_for_docker; then
        printf 'Enabled: %s\n' "$(/usr/bin/docker --version)"
      else
        warn 'Docker Desktop started, but /usr/bin/docker has not appeared yet. Check Settings > Resources > WSL integration.'
      fi
    else
      printf 'Skipped. Enable it later in Docker Desktop: Settings > Resources > WSL integration.\n'
    fi
  fi
fi

# ---------------------------------------------------------------------------
step 'VS Code: Remote - WSL'
# VS Code runs on Windows and reaches this distribution through the WSL extension.
# The Windows "code" launcher is on PATH through WSL interop when VS Code is installed.
if command -v code >/dev/null; then
  if code --install-extension ms-vscode-remote.remote-wsl --force >/dev/null; then
    printf 'Remote - WSL extension installed. Run "code ." in any project.\n'
  else
    warn 'Could not install the Remote - WSL extension; install it from VS Code on Windows.'
  fi
else
  warn 'VS Code was not found on Windows. Install it there (winget install Microsoft.VisualStudioCode) and rerun.'
fi

# ---------------------------------------------------------------------------
step 'Installed versions'
for t in go dotnet cargo rustc tsc claude codex copilot docker code; do
  if [[ $t == docker ]]; then
    # Only the Linux client from Docker Desktop's WSL integration counts, not the Windows stub.
    if [[ -x /usr/bin/docker ]]; then
      printf '%-9s %s\n' docker "$(/usr/bin/docker --version)"
    else
      printf '%-9s MISSING (enable Docker Desktop WSL integration)\n' docker
    fi
    continue
  fi
  if command -v "$t" >/dev/null; then
    case $t in
      go) v=$(go version 2>/dev/null || true) ;;
      *) v=$("$t" --version 2>/dev/null | head -1 || true) ;;
    esac
    printf '%-9s %s\n' "$t" "${v:-installed}"
  else
    printf '%-9s MISSING\n' "$t"
  fi
done
printf '\nDone. Open a new terminal to pick up the shell changes.\n'
