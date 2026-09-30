# Agentic tools verification

Verified on 2026-09-17 in `Ubuntu-Nix-Test`.

All 13 tools from `savviety-skills/bin/install-agentic-tools` are managed by Nix: ripgrep, fd, jq, rsync, shellcheck, ast-grep, sd, gh, gh-axi, just, hyperfine, xh, and defuddle. The existing Nix-managed uv and Python satisfy the installer's prerequisites.

Twelve packages come from the existing pinned Nixpkgs revision. The custom gh-axi package uses version 0.1.35 with locked npm dependencies and a verified dependency-cache hash. Package installation runs inside the Nix build; activation does not run global npm installs or the upstream installer.

Home Manager now includes `~/.local/bin` on PATH even when the directory does not exist. This resolves the upstream check's failure on a fresh home directory.

Validation passed:

- The original installer ran in `--check` mode before and after a full reset and rebuild, returning exit code 0 and `All tools present.` No installation mode was used.
- Clean-shell checks confirmed that all tool commands resolve into the Nix store.
- Functional checks covered gh-axi's version and subcommand help, AST search, text replacement, rsync copying, ShellCheck, hyperfine, xh startup, and defuddle parsing a local HTML file.
- The existing shell, Node/pnpm, Python/uv, and project environment checks still passed.
- The activation store path matched before reset, after rebuilding from the blank baseline, and after applying again. Both the Nix and npm lock files were unchanged.
- ShellCheck, Zsh syntax checks, and Python compilation passed for the local scripts.

[Installer output](agentic-tools-check.txt) records the command paths. [Build evidence](agentic-tools-build.json) records the matching activation paths, lock hashes, and the checksum of the installer used for verification.

Authenticated GitHub operations were not tested. Credentials and optional gh-axi hooks are separate setup steps. The source installer in `savviety-skills` was unchanged. These changes are local and have not been committed or published.
