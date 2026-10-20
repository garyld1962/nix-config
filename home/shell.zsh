# Shell preferences carried over from the working Ubuntu environment.
# Home Manager supplies completion, history, direnv, fzf, and the Starship prompt.
typeset -U path PATH

# Windows Terminal and wsl.exe start in the Windows profile or System32.
# Move to the Linux home in that case; any other start directory is kept.
if [[ $PWD =~ ^/mnt/c/[Uu]sers/[^/]+$ || ${PWD:l} == /mnt/c/windows/system32 ]]; then
  cd ~
fi

setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt COMBINING_CHARS
unsetopt BEEP

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME}/zsh/zcompcache"
bindkey -e

__wezterm_osc7() {
  [[ -n ${WEZTERM_PANE:-} ]] || return 0

  emulate -L zsh
  local LC_ALL=C encoded='' char
  local i

  for (( i = 1; i <= ${#PWD}; i++ )); do
    char=${PWD[i]}
    case $char in
      [[:alnum:]/._~-]) encoded+=$char ;;
      *)
        printf -v char '%%%02X' "'$char"
        encoded+=$char
        ;;
    esac
  done

  printf '\e]7;file://%s%s\e\\' "${HOST:-$HOSTNAME}" "$encoded"
}

autoload -Uz add-zsh-hook
add-zsh-hook -d precmd __wezterm_osc7 2>/dev/null
add-zsh-hook precmd __wezterm_osc7


# Small, portable shell helpers.  Each helper avoids framework dependencies and
# works on both WSL/Linux and macOS where practical.

lsw() {
  emulate -L zsh

  if (( $+commands[eza] )); then
    command eza --group-directories-first --icons=auto --long --git --time-style=long-iso "$@"
  else
    command ls -lah "$@"
  fi
}

ff() {
  emulate -L zsh

  if (( $# < 1 || $# > 2 )); then
    print -u2 'Usage: ff <name-fragment> [path]'
    return 64
  fi

  local needle=$1
  local root=${2:-.}
  [[ -d $root ]] || { print -u2 "Not a directory: $root"; return 66; }

  if (( $+commands[fd] )); then
    command fd --type f --ignore-case --glob "*${needle}*" "$root"
  elif (( $+commands[fdfind] )); then
    command fdfind --type f --ignore-case --glob "*${needle}*" "$root"
  else
    command find "$root" -type f -iname "*${needle}*" -print
  fi
}

diskpig() {
  emulate -L zsh

  local root=${1:-.}
  local depth=${2:-1}
  [[ -d $root ]] || { print -u2 "Not a directory: $root"; return 66; }
  [[ $depth == <-> ]] || { print -u2 'Depth must be a non-negative integer'; return 64; }

  command du -h -d "$depth" "$root" 2>/dev/null | command sort -hr | command head -n 20
}

port() {
  emulate -L zsh

  if (( $# > 1 )); then
    print -u2 'Usage: port [number]'
    return 64
  fi

  local port_number=${1:-}
  if [[ -n $port_number && $port_number != <-> ]]; then
    print -u2 'Port must be numeric'
    return 64
  fi

  if (( $+commands[ss] )); then
    if [[ -n $port_number ]]; then
      command ss -ltnp | command grep -F ":$port_number"
    else
      command ss -ltnp
    fi
  elif (( $+commands[lsof] )); then
    if [[ -n $port_number ]]; then
      command lsof -nP -iTCP:"$port_number" -sTCP:LISTEN
    else
      command lsof -nP -iTCP -sTCP:LISTEN
    fi
  else
    print -u2 'Neither ss nor lsof is installed'
    return 127
  fi
}

extract() {
  emulate -L zsh
  [[ -n ${1:-} ]] || { print -u2 'Usage: extract <archive>'; return 64; }
  [[ -f $1 ]] || { print -u2 "Not a file: $1"; return 66; }

  case $1 in
    *.tar.gz|*.tgz)   command tar xzf "$1" ;;
    *.tar.bz2|*.tbz2) command tar xjf "$1" ;;
    *.tar.xz)         command tar xJf "$1" ;;
    *.zip)            command unzip "$1" ;;
    *.gz)             command gunzip "$1" ;;
    *.bz2)            command bunzip2 "$1" ;;
    *)
      print -u2 "Unsupported archive type: $1"
      return 65
      ;;
  esac
}

jqp() {
  emulate -L zsh
  if (( $# )); then
    command jq '.' "$1"
  else
    command jq '.'
  fi
}

up() {
  emulate -L zsh
  [[ -n ${1:-} ]] || { print -u2 'Usage: up <url>'; return 64; }

  local url=$1
  [[ $url == http://* || $url == https://* ]] || url="https://$url"
  command curl --max-time 10 -sS -o /dev/null \
    -w 'Status: %{http_code}  Time: %{time_total}s  Size: %{size_download} bytes\n' \
    "$url"
}

serve() {
  emulate -L zsh

  local port_number=${1:-8000}
  [[ $port_number == <-> ]] || { print -u2 'Port must be numeric'; return 64; }

  if (( $+commands[python3] )); then
    print "Serving $(pwd) on http://localhost:$port_number"
    command python3 -m http.server "$port_number"
  elif (( $+commands[python] )); then
    print "Serving $(pwd) on http://localhost:$port_number"
    command python -m http.server "$port_number"
  else
    print -u2 'Python is not installed'
    return 127
  fi
}

wttr() {
  emulate -L zsh
  [[ -n ${1:-} ]] || { print -u2 'Usage: wttr <place>'; return 64; }
  command curl -s "https://wttr.in/${1}?format=3"
}

helpers() {
  cat <<'EOF'
Custom helpers:
  lsw [path]               Directory listing (uses eza when installed)
  ff <fragment> [path]     Find files by name fragment
  diskpig [path] [depth]   Largest directories
  port [number]            Listening TCP ports
  extract <archive>        Extract a common archive type
  jqp [file]               Pretty-print JSON
  up <url>                 HTTP status and timing
  serve [port]             Serve the current directory
  wttr <place>             Compact weather
EOF
}

reload-zsh() { source "$HOME/.zshrc"; }
# Optional machine-local settings stay outside the reproducible configuration.
[[ ! -r "$HOME/.config/zsh/local.zsh" ]] || source "$HOME/.config/zsh/local.zsh"
