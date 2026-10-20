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
for t in go dotnet cargo rustc tsc claude codex copilot code; do
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
