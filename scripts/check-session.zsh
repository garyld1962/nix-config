set -eu
for tool in nix home-manager zsh starship direnv git rg fd fzf bat jq tmux just curl wget node npm pnpm python3 uv rsync shellcheck ast-grep sd gh gh-axi hyperfine xh defuddle herdr wsl-open sox; do
  executable=$(command -v "$tool")
  resolved=$(readlink -f "$executable")
  [[ $resolved == /nix/store/* ]] || { print -u2 "Tool is outside Nix: $tool ($resolved)"; exit 1; }
done
[[ :$PATH: == *:$HOME/.local/bin:* ]]
(( ! $+functions[__wezterm_osc7] ))
[[ $BROWSER == wsl-open ]]
[[ $PULSE_SERVER == unix:/mnt/wslg/PulseServer ]]
sox --help 2>&1 | grep -q '^AUDIO DEVICE DRIVERS:.*pulseaudio'
[[ $(readlink -f "$(command -v xdg-open)") == /nix/store/* ]]
[[ $(readlink -f "$(command -v open)") == /nix/store/* ]]
rc=0; wsl-open >/dev/null 2>&1 || rc=$?
(( rc == 64 ))
if [[ -d /mnt/c ]]; then
  # check-shared.sh seeds PATH with fake Windows entries; the filter in home/shell.zsh
  # must keep only the VS Code launcher.
  [[ :$PATH: != *system32* ]]
  [[ :$PATH: != *'/Docker/Docker/resources/bin:'* ]]
  [[ :$PATH: == *'/Microsoft VS Code/bin:'* ]]
  [[ $(WSL_OPEN_DRY_RUN=1 wsl-open https://example.com) == 'rundll32.exe url.dll,FileProtocolHandler https://example.com' ]]
fi
[[ $(herdr --version) == 'herdr 0.7.5' ]]
[[ $(node --version) == v22.* ]]
[[ $(pnpm --version) == 10.* ]]
[[ $(python3 --version) == 'Python 3.12.'* ]]
(( ! $+functions[nvm] ))
[[ $HISTSIZE == 50000 && $SAVEHIST == 50000 ]]
[[ -o sharehistory && -o histignorespace && -o autocd ]]
(( $+functions[compdef] && $+functions[_direnv_hook] ))
[[ $HISTFILE == "$HOME/.zsh_history" ]]
[[ $ZSH_NAME == zsh ]]
nix flake metadata --no-update-lock-file "$CONFIG_ROOT" --json | jq -e '.locks.nodes.nixpkgs.locked.rev' >/dev/null
[[ $(git config --global --get-all include.path) == "$HOME/.config/git/personal.inc" ]]

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cd "$work"
printf '%s\n' '{"name":"wsl-nix-smoke","version":"1.0.0","scripts":{"test":"node check.cjs"}}' > package.json
printf '%s\n' 'require("node:assert/strict").equal(2 + 2, 4); console.log("PASS: Node project via pnpm");' > check.cjs
pnpm install --offline --ignore-scripts
pnpm test

uv venv --offline --python python3 .venv
.venv/bin/python -c 'import sys, json; assert sys.version_info[:2] == (3, 12); print("PASS: uv creates a Python 3.12 environment")'
printf '%s\n' '{"ok":true}' | jqp | jq -e '.ok' >/dev/null
printf 'sample\n' > searchable.txt
ff searchable | rg searchable.txt >/dev/null
mkdir child
printf '%s\n' 'export NIX_LAB_DIRENV_TEST=works' > child/.envrc
direnv allow child
direnv exec child /usr/bin/sh -c 'test "$NIX_LAB_DIRENV_TEST" = works'
starship prompt >/dev/null
mkdir -p junk/nested
touch junk/Thumbs.db junk/desktop.ini junk/nested/report.pdf:Zone.Identifier junk/nested/keep.txt junk/keep.db
mkdir -p 'junk/$RECYCLE.BIN/S-1-5-21'
[[ $(winjunk -n junk | tail -1) == '4 item(s) would be removed (dry run)' ]]
[[ -f junk/Thumbs.db ]]
winjunk -y junk >/dev/null
[[ ! -e junk/Thumbs.db && ! -e junk/desktop.ini && ! -e junk/nested/report.pdf:Zone.Identifier && ! -e 'junk/$RECYCLE.BIN' ]]
[[ -f junk/nested/keep.txt && -f junk/keep.db ]]
[[ $(winjunk -y junk) == "No Windows metadata files under junk" ]]
git init -q git-test
print 'PASS: clean Zsh login, Nix command paths, Windows PATH filter, wsl-open, history, completion, helpers, direnv, prompt, and Git'

# Exercise the additional agent utilities without credentials or remote services.
[[ $(gh-axi --version) == 0.1.35 ]]
gh-axi issue --help > gh-axi-help.txt
rg -q 'usage: gh-axi issue' gh-axi-help.txt
gh --version >/dev/null
xh --version >/dev/null
hyperfine --runs 1 --warmup 0 --shell=none 'sleep 0.01' > timing.txt
printf '%s\n' '#!/bin/sh' 'printf "%s\n" hello' > sample.sh
shellcheck sample.sh
printf '%s\n' 'console.log("hello");' > sample.js
ast-grep run --pattern 'console.log($A)' --lang javascript --json sample.js > matches.json
jq -e 'length == 1' matches.json >/dev/null
sd hello goodbye sample.js
rg -q goodbye sample.js
mkdir copied
rsync sample.js copied/
cmp sample.js copied/sample.js
printf '%s\n' '<html><head><title>Agentic tools smoke test</title></head><body><article><h1>Agentic tools smoke test</h1><p>These local tools are installed by Nix and checked without accessing a remote service.</p></article></body></html>' > article.html
defuddle parse article.html --json > article.json
jq -e '.title == "Agentic tools smoke test"' article.json >/dev/null
print 'PASS: agentic CLI startup, code search, replacement, file copy, shell analysis, timing, and HTML parsing'
node --version
pnpm --version
python3 --version
uv --version
