# Reproducible WSL configuration

Nix and Home Manager manage the first set of shell and development tools in `Ubuntu-Nix-Test`. Your working `Ubuntu` remains the default WSL distribution. Nix replaces NVM only in the test instance.

## Try the environment

Open it from Windows PowerShell:

```powershell
wsl -d Ubuntu-Nix-Test --cd '~'
```

You will enter Zsh as `gary`, with your Starship prompt and portable shell helpers. The first configuration includes:

- Git, direnv with nix-direnv, ripgrep, fd, fzf, bat, jq, tmux, just, curl, wget, and common archive tools.
- Node 22, pnpm 10, Python 3.12, and uv.
- Shared shell history, completion preferences, WezTerm directory reporting, and helpers such as `ff`, `diskpig`, `jqp`, `serve`, and `extract`.
- Herdr 0.7.5, matching the official binary in your working Ubuntu, with Zsh as its shell and your terminal theme settings.
- The full `savviety-skills/bin/install-agentic-tools` toolset: ripgrep, fd, jq, rsync, shellcheck, ast-grep, sd, gh, gh-axi, just, hyperfine, xh, and defuddle.

The tested versions are Node 22.23.2, pnpm 10.34.0, Python 3.12.14, and uv 0.11.21. [flake.lock](flake.lock) pins the exact Nixpkgs and Home Manager revisions and content hashes. The bootstrap separately pins and verifies the Nix 2.35.2 installer, whose installer verifies its binary archive.

The [verification results](assessment/first-pass-verification.md) cover a full reset and rebuild, repeated application, and a restart. The rebuild produced the same activation store path with an unchanged lock file.

## Change and apply the configuration

Edit the source files in your working Ubuntu at `/home/gary/repos/nix-config`. The copy inside the test instance is disposable.

| File | Purpose |
| --- | --- |
| [home/default.nix](home/default.nix) | Packages, shell integration, and user settings |
| [home/agentic-tools.nix](home/agentic-tools.nix) | The agentic tools package set |
| [packages/gh-axi/default.nix](packages/gh-axi/default.nix) | Custom package for gh-axi 0.1.35; adjacent npm lock file pins its dependencies |
| [packages/herdr/default.nix](packages/herdr/default.nix) | Herdr 0.7.5 official Linux binary, pinned by checksum |
| [home/herdr.toml](home/herdr.toml) | Herdr settings managed by Home Manager |
| [home/shell.zsh](home/shell.zsh) | Portable shell preferences and helpers |
| [home/starship.toml](home/starship.toml) | Prompt appearance |
| [flake.nix](flake.nix) | Inputs, Home Manager configuration, and a project development shell |
| [flake.lock](flake.lock) | Exact dependency revisions used for builds |

From the source folder in your working Ubuntu:

```bash
python3 scripts/lab.py apply
python3 scripts/lab.py test
```

The first command copies the configuration to the test instance and activates it. The second checks a clean Zsh login, Nix-managed command paths, shell helpers, direnv, a Node project run through pnpm, a Python environment created by uv, and the project development shell. The scripts refuse to run against any distribution other than the marked `Ubuntu-Nix-Test` instance.

Agentic tool checks also cover CLI startup, code search, text replacement, file copying, shell analysis, timing, and local HTML parsing. All 13 tools are installed through Nix. `gh-axi` uses a custom package with a locked npm dependency tree and a verified dependency-cache hash; no global npm installation runs during activation. GitHub authentication and optional hooks are separate from installing the tools.

The [agentic tools verification](assessment/agentic-tools-verification.md) includes a fresh reset and rebuild, repeated activation, and a successful `--check` run of the original installer.

Home Manager puts `~/.local/bin` on PATH even before that directory exists, so uv's tool-directory check succeeds on a fresh setup. Tools installed there manually remain outside the Nix configuration.

Run `herdr` inside `Ubuntu-Nix-Test` to open the terminal workspace manager. Its settings come from `home/herdr.toml`; edit that source file and apply the configuration to change them. Keep Herdr updates in the Nix package definition rather than running its self-updater, as described in the [Herdr installation documentation](https://herdr.dev/docs/install/). Existing session state, logs, plugins, and agent credentials are not copied from your working Ubuntu.

The smoke tests start a temporary named Herdr session with isolated settings, run Zsh and Node in a real pane, and stop only that temporary session afterward.

Open a fresh terminal after applying shell changes. Inside the test copy, `nix develop path:.` opens the example project environment using the same pinned runtimes. Individual projects can later define their own development environments.

Python environments use the configured interpreter. Automatic Python downloads through uv are disabled with `UV_PYTHON_DOWNLOADS=never`; additional Python versions should be declared in Nix or deliberately enabled for a particular project.

## Rebuild from the blank baseline

From the source folder in your working Ubuntu:

```bash
python3 scripts/lab.py rebuild
```

This deletes the test instance's current filesystem, restores the saved Ubuntu baseline, installs Nix, applies the existing lock file, and runs the checks. Keep work you want to retain outside the test instance. The source configuration stays in your working Ubuntu throughout.

The baseline is `C:\Users\sql_1\WSL\nix-lab\ubuntu-24.04-blank.tar`. It contains Ubuntu 24.04.5, the `gary` account with passwordless sudo, systemd, and an identifying marker. It contains no Nix installation. A checksum is checked before reset. The same Windows directory stores the original Canonical image and its provenance.

To restore only that blank baseline, run this in Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '\\wsl.localhost\Ubuntu\home\gary\repos\nix-config\scripts\wsl-lab.ps1' -Action Reset
```

After a blank reset, `python3 scripts/lab.py bootstrap` installs Nix without applying Home Manager. The `lock` action creates a missing lock file; it does not deliberately update existing pins. Dependency updates are a separate change and should be reviewed and tested.

A reset restores the saved image, not a newly downloaded Ubuntu release. Bootstrap and package installation require network access. This is a disposable Linux filesystem, not a security sandbox: it can still access Windows files.

## Migration boundaries

Docker, GPU support, AI coding assistants, browser automation, credentials, Git identity, repositories, and application data are outside this first pass. Docker helpers and archive formats requiring 7-Zip or unrar were omitted. Optional personal shell settings can live in `~/.config/zsh/local.zsh`; that file is not managed or restored by this configuration.

Home Manager backs up the stock Ubuntu `.profile` and `.bashrc` with a `.before-nix` suffix on first activation. Ubuntu still owns the base operating system and system services. This configuration currently targets the `gary` account on x86-64 Ubuntu WSL; it is not yet a general installer for other users or machines.

The [initial inventory](assessment/inventory.json) records migration candidates without credentials.

## References

- [Nix installation on WSL2](https://nixos.org/download/)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Microsoft WSL import, export, and unregister commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)
