# Shared development environment for Ubuntu WSL

Create an Ubuntu WSL distribution, install Git, clone this repository, and run one bootstrap script. The script installs Nix and applies the shared development tools and shell configuration for your own account. Ubuntu remains the operating system; this does not install NixOS.

Personal identities, authentication, 1Password, and API keys belong in a separate private installer. The shared environment works without them.

## Install

From a normal (not elevated) PowerShell window on Windows 11 22H2 or newer:

```powershell
irm https://raw.githubusercontent.com/garyld1962/nix-config/main/dev-setup.ps1 | iex
```

The script:

- prompts for your Linux username and password, then shows a summary and asks for confirmation before changing anything;
- installs or updates WSL 2 and enables mirrored networking in `.wslconfig` (if WSL was missing, it asks you to reboot and rerun);
- imports Ubuntu 26.04.1 LTS from a checksum-verified image into `%LOCALAPPDATA%\WSL\Ubuntu`;
- clones this repository inside the new distribution and runs `bootstrap.sh` as your user.

Rerunning the same command after a failure resumes without creating a second distribution. The one-line install needs the repository to be public. From a clone, `dev-setup.ps1 -Distro <name> -Branch <branch>` installs under another name or from a branch, `dev-check.ps1 -Distro <name>` validates the result (Windows side, inside the distribution, then the shared checks), and `dev-reset.ps1 -Distro <name>` removes a distribution that dev-setup created. [The test runbook](docs/dev-setup-testing.md) records how to exercise all three end to end and the results of the last run.

### Already have a distribution?

Ubuntu 26.04 is the tested base. This environment supports x86-64 Ubuntu WSL with systemd and an account that can use `sudo`. Inside Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/garyld1962/nix-config.git
cd nix-config
bash bootstrap.sh
```

The bootstrap ensures curl, Git, Python, xz, and CA certificates are available. It installs Nix 2.35.2 using a checksum-verified installer when Nix is absent. It preserves an existing usable Nix installation, enables the Nix daemon, builds the shared profile using the checked-in lock file, and activates Home Manager.

The script detects your username and home directory. Run it as your normal account, not with `sudo bash`. It changes your login shell to the managed Zsh. To retain your current login shell:

```bash
bash bootstrap.sh --no-change-shell
```

If systemd is disabled, add this section to `/etc/wsl.conf` without removing existing settings, then run `wsl --shutdown` from Windows and reopen Ubuntu:

```ini
[boot]
systemd=true
```

Open a new terminal after installation.

## Shared tools and defaults

The current shared profile contains the tools already verified in the original lab. [The tool list](docs/shared-environment.md) is the starting point for reviewing the opinionated environment.

- Git, GitHub CLI and gh-axi, direnv with nix-direnv, common command-line and archive tools.
- Node 22, pnpm 10, Python 3.12, and uv.
- Zsh, Starship, completion, shared history, and portable shell helpers.
- Herdr 0.7.5 with Zsh and the terminal theme.
- Agent utilities for code search, replacement, copying, shell analysis, timing, HTTP requests, and HTML parsing.

Optional modules extend the profile per account. `toolchains` adds Go, .NET SDK 10, rustup with a gcc linker, and TypeScript. List the module name in `~/.config/shared-dev/modules` (one per line) and reapply; `post-install.sh` does this.

[flake.lock](flake.lock) pins Nixpkgs and Home Manager. The gh-axi package also has a locked npm dependency tree. Package installation happens in Nix builds; activation does not run global npm installs.

Python environments use the configured interpreter. Automatic Python downloads through uv are disabled with `UV_PYTHON_DOWNLOADS=never`.

## Apply changes and check the environment

Keep the clone at its installed location. The generated user profile refers to that local source. After reviewing and pulling changes, run:

```bash
bash scripts/apply-shared.sh
bash scripts/check-shared.sh
```

The generated profile lives in `~/.config/shared-dev` (or under `XDG_CONFIG_HOME` when set). It contains your username, home directory, local source reference, and its lock file. It is generated automatically and contains no credentials. The script refuses to overwrite a manually maintained profile at that location.

Applying updates refreshes the local source input while retaining the versions pinned by the shared repository. Existing stock dotfiles that conflict with Home Manager are backed up with a `.before-shared-dev` suffix. If such a backup already exists, resolve the collision rather than overwriting it.

The checks use a clean Zsh environment, verify that shared commands resolve into the Nix store, and exercise Node/pnpm, Python/uv, direnv, shell helpers, and the agent utilities. A temporary Herdr session runs Zsh and Node in a real pane and stops only its own server. Checks create temporary projects; they do not reset your WSL distribution.

For the example project environment:

```bash
nix develop path:.
```

## Personal setup

Run your private installer separately after the shared bootstrap. [The personal setup contract](docs/personal-setup.md) describes the files it can manage and how to extend the shared Home Manager module.

[post-install.sh](post-install.sh) is the personal installer for this repository. Run it once after the bootstrap, as your own user, from the clone:

```bash
bash post-install.sh
```

It prompts for your Git name and email, signs you in to GitHub with `gh`, enables the optional `toolchains` module (Go, the .NET SDK, Rust, TypeScript) in your profile and reapplies it, and installs Claude Code, Codex, and Copilot CLI into `~/.local`. VS Code stays on Windows; the script adds the Remote - WSL extension so `code .` opens this distribution. Rerunning it updates the tools and keeps your answers as defaults.

The shared Git configuration includes the optional `~/.config/git/personal.inc` file. Zsh loads the optional `~/.config/zsh/local.zsh` file. Reapplying the shared configuration does not manage or replace either file.

Authentication and secret values stay outside Nix configuration and the Nix store. The bootstrap does not read a personal vault or copy credentials from another account.

Docker, GPU support, AI coding assistants, browser automation, repositories, and application data are not yet part of this shared profile. We will review these additions separately.

## Maintain the shared configuration

| File | Purpose |
| --- | --- |
| [dev-setup.ps1](dev-setup.ps1) | Windows entry point: WSL prerequisites, Ubuntu import, user, bootstrap |
| [dev-reset.ps1](dev-reset.ps1) | Removes a distribution that dev-setup created |
| [dev-check.ps1](dev-check.ps1) | Validates a distribution that dev-setup created |
| [scripts/wsl-common.ps1](scripts/wsl-common.ps1) | PowerShell functions shared by dev-setup, dev-reset, and the lab |
| [bootstrap.sh](bootstrap.sh) | Master installer for a developer's Ubuntu WSL account |
| [post-install.sh](post-install.sh) | Personal installer: identity, GitHub sign-in, extra toolchains |
| [scripts/install-nix.sh](scripts/install-nix.sh) | Ubuntu prerequisites and pinned Nix bootstrap |
| [scripts/apply-shared.sh](scripts/apply-shared.sh) | Generate, build, and activate the current user's profile |
| [home/default.nix](home/default.nix) | Shared packages and shell configuration |
| [home/agentic-tools.nix](home/agentic-tools.nix) | Shared agent utilities |
| [home/toolchains.nix](home/toolchains.nix) | Optional module: Go, .NET SDK, rustup, gcc, TypeScript |
| [home/shell.zsh](home/shell.zsh) | Shell preferences and helpers |
| [home/starship.toml](home/starship.toml) | Shared prompt |
| [home/herdr.toml](home/herdr.toml) | Shared Herdr settings |
| [packages](packages) | Custom pinned gh-axi and Herdr packages |
| [flake.nix](flake.nix) | Shared module, configuration factory, and project shell |

Run local checks before delivery:

```bash
shellcheck bootstrap.sh post-install.sh scripts/*.sh
zsh -n home/shell.zsh scripts/check-session.zsh
python3 -m py_compile scripts/*.py
python3 -m unittest discover -s tests -v
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Set-Location $env:TEMP; Invoke-ScriptAnalyzer -Path '$(wslpath -w .)' -Recurse -Severity Warning,Error"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Set-Location $env:TEMP; Import-Module Pester -MinimumVersion 5.0; Invoke-Pester -Path '$(wslpath -w tests)'"
```

## Disposable verification lab

The original `Ubuntu-Nix-Test` lab remains separate from the developer installer. Its fixed `gary` account, identifying marker, and saved baseline are test fixtures. The lab calls the same shared installation code.

From the source repository in the working Ubuntu:

```bash
python3 scripts/lab.py apply
python3 scripts/lab.py test
python3 scripts/lab.py rebuild
```

`rebuild` deletes the marked test distribution, restores its checksum-verified blank baseline, installs Nix, applies the shared profile, and runs the checks. Keep anything you want to retain outside that distribution. These reset commands are not part of the training installation and refuse to operate on other distributions.

The baseline lives under the current Windows user's `WSL\nix-lab` directory. A baseline restores the saved Ubuntu image; it does not fetch a newer release. WSL can access Windows files, so the disposable distro is not a security sandbox.

The [shared bootstrap verification](assessment/shared-dev-verification.md) covers a fresh developer account, personal-file preservation, and a blank-baseline rebuild. Historical verification and the original machine inventory remain under [assessment](assessment). They describe the original lab and should not be treated as a developer's personal configuration or copied into their private setup.

## References

- [Nix installation](https://nix.dev/manual/nix/2.35/installation/installing-binary)
- [Home Manager](https://github.com/nix-community/home-manager)
- [WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install)
