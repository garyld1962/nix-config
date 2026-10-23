# Shared tools and defaults

This is the first shared profile. It carries over the tools from the verified WSL lab and removes fixed developer identities. Use this list to review what every developer should receive before expanding the environment.

| Area | Included |
| --- | --- |
| Runtimes | Node 22, npm, pnpm 10, Python 3.12, uv |
| Shell | Zsh, Starship, Bash integration, fzf completion, shared history |
| Project environments | direnv, nix-direnv, example Nix development shell |
| Version control | Git, gh, gh-axi 0.1.35; authentication is separate |
| Search and text | ripgrep, fd, jq, bat, ast-grep, sd |
| Files and archives | rsync, unzip, zip, tar, gzip, bzip2, xz |
| Network | curl, wget, xh, iproute2 |
| Workflow | tmux, just, ShellCheck, hyperfine, defuddle |
| Audio | SoX (`sox`, `play`, `rec`) with the PulseAudio driver; `PULSE_SERVER` points at the WSLg sound server |
| Terminal workspaces | Herdr 0.7.5, tuios 0.10.1 |

The shared prompt shows the directory, Git state, command duration, and active project runtimes. History holds 50,000 entries and is shared between Zsh sessions. Completion skips directories that Zsh considers insecure, so a second account does not wait at an interactive trust prompt. Herdr uses Zsh and the terminal theme. uv uses the configured Python and does not automatically download other versions.

Shell helpers include directory listing, filename search, disk usage, listening ports, archive extraction, JSON formatting, HTTP checks, a local HTTP server, weather for an explicitly supplied place, and `winjunk` to remove the metadata files Windows Explorer leaves in Linux folders (Thumbs.db, desktop.ini, recycle-bin folders, and `:Zone.Identifier` files). On WSL the Windows entries that WSL appends to PATH are dropped, except for the VS Code launcher; Docker comes from Docker Desktop's WSL integration instead. `wsl-open` (also available as `xdg-open` and `open`, and set as `BROWSER`) opens URLs and files with the Windows default handler.

The shared profile contains no Git identity, vault reference, account token, personal location, or authentication setup. Optional personal Git and shell files are loaded at runtime.

## Optional modules

| Module | Included | Enable |
| --- | --- | --- |
| `toolchains` | Go, .NET SDK 10, rustup, gcc, TypeScript | `~/.config/shared-dev/modules`; see the personal setup contract |

## Selected additions

These tools are selected for the shared environment but are not yet installed by the shared bootstrap.

| Area | Tool | Purpose | Install status |
| --- | --- | --- | --- |
| HTML documents and review | Lavish Editor (`lavish-axi`) | Open HTML documents for visual review, annotations, and feedback; export standalone HTML files | Nix packaging and shared installation pending |

AI assistants, browser automation, Docker, and GPU tooling still need a tool-by-tool review. Claude Code, Codex, and Copilot CLI are installed per account by `post-install.sh` because they update faster than a pinned flake. The original machine inventory records candidates, not a decision to install everything it contains.
