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
| Terminal workspaces | Herdr 0.7.5 |

The shared prompt shows the directory, Git state, command duration, and active project runtimes. History holds 50,000 entries and is shared between Zsh sessions. Completion skips directories that Zsh considers insecure, so a second account does not wait at an interactive trust prompt. Herdr uses Zsh and the terminal theme. uv uses the configured Python and does not automatically download other versions.

Shell helpers include directory listing, filename search, disk usage, listening ports, archive extraction, JSON formatting, HTTP checks, a local HTTP server, and weather for an explicitly supplied place. WezTerm directory reporting is enabled when running inside WezTerm.

The shared profile contains no Git identity, vault reference, account token, personal location, or authentication setup. Optional personal Git and shell files are loaded at runtime.

## Selected additions

These tools are selected for the shared environment but are not yet installed by the shared bootstrap.

| Area | Tool | Purpose | Install status |
| --- | --- | --- | --- |
| HTML documents and review | Lavish Editor (`lavish-axi`) | Open HTML documents for visual review, annotations, and feedback; export standalone HTML files | Nix packaging and shared installation pending |

AI assistants, browser automation, Docker, GPU tooling, and additional language runtimes still need a tool-by-tool review. The original machine inventory records candidates, not a decision to install everything it contains.
