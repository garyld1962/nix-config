# dev-setup: one-command Ubuntu WSL developer bootstrap

Status: approved design, 2026-10-19. Implementation plan follows separately.

## Goal

A freshly reset Windows laptop reaches a working shared development environment after one PowerShell command. The user chooses their Linux username and password before any software is installed. WSL uses mirrored networking. The Ubuntu side runs the existing `bootstrap.sh` unchanged.

Companion: a reset script that removes a distro dev-setup created so the install can be rerun from scratch.

Out of scope: bare-metal Ubuntu, the private personal installer, GitHub authentication, Docker or GPU support.

## Decisions already made

- Target is Ubuntu under WSL 2, not bare metal.
- Entry point is a single PowerShell command; the Ubuntu side is driven imperatively by PowerShell (not cloud-init, not a first-boot systemd unit).
- The repository becomes public so first boot can clone over HTTPS without credentials.
- Base image moves from Ubuntu 24.04.5 to Ubuntu 26.04.1 LTS for both dev-setup and the verification lab.
- Password is piped to `chpasswd` over stdin. It is never written to disk, a command line, or the console.

## Files

| File | Role |
| --- | --- |
| `dev-setup.ps1` (repo root) | Entry point. Prompts, Windows prerequisites, distro creation, bootstrap. |
| `dev-reset.ps1` (repo root) | Removes a distro that dev-setup created. |
| `scripts/wsl-common.ps1` | Shared functions: WSL invocation, distro listing, image download and verification, import, root user setup. Dot-sourced by `dev-setup.ps1`, `dev-reset.ps1`, and `scripts/wsl-lab.ps1`. |
| `scripts/wsl-lab.ps1` | Existing lab, rebased on `wsl-common.ps1` and Ubuntu 26.04.1. |
| `tests/*.Tests.ps1` | Pester tests for pure PowerShell functions. |
| `README.md` | Install section replaced by the one-liner; tested base becomes 26.04. |

## dev-setup.ps1

### Parameters

- `-Distro` (default `Ubuntu`). Name of the WSL distribution to create. Also sets the install directory `%LOCALAPPDATA%\WSL\<Distro>`.
- `-Repo` (default `https://github.com/garyld1962/nix-config.git`) and `-Branch` (default `main`). Exist so a branch can be tested before merge.
- `-NoChangeShell` passes `--no-change-shell` through to `bootstrap.sh`.

Invocation on a fresh machine:

```powershell
irm https://raw.githubusercontent.com/garyld1962/nix-config/main/dev-setup.ps1 | iex
```

When run through `iex` there is no `$PSScriptRoot`, so the script fetches `scripts/wsl-common.ps1` from the same repository and branch into a temporary directory and dot-sources it. When run as a file with a sibling `scripts/wsl-common.ps1`, it dot-sources the local copy. The fetched copy is verified only by HTTPS; pinning a hash is not required because the entry script itself arrives the same way.

### Stage 0: guards

- Refuses to run elevated. WSL distributions are per user and the install directory must belong to the interactive user.
- Requires Windows 10 build 19041 or Windows 11; mirrored networking additionally requires Windows 11 22H2 (build 22621) and WSL 2.0.0 or newer. Older systems fail with a clear message before any change.
- Refuses to continue if `-Distro` names an existing distribution that dev-setup did not create (see marker below). Prints how to pick another name or remove it.

### Stage 1: prompts, before any install

1. Username. Validated against Ubuntu's `NAME_REGEX`: `^[a-z][-a-z0-9_]*$`, at most 32 characters, not `root`.
2. Password, read as a SecureString, entered twice, must match, non-empty.
3. Summary (distro name, install path, username, mirrored networking, image version) and a yes/no confirmation. Any other answer exits with no changes.

The plaintext is materialised only inside the process as a single string for the stdin pipe in Stage 3 and cleared afterwards.

### Stage 2: Windows prerequisites

1. `wsl --status`. If WSL is absent or the command fails, run `wsl --install --no-distribution`, print "Reboot, then run the same command again", and exit 0. Nothing else has changed at this point.
2. `wsl --update` (non-fatal if the Store is unreachable; version check still runs).
3. `wsl --version` must report 2.0.0 or newer.
4. Merge `networkingMode=mirrored` into `%USERPROFILE%\.wslconfig`:
   - File absent: create it with a `[wsl2]` section and the key.
   - `[wsl2]` section present with `networkingMode` already set to `mirrored` (case-insensitive): no change.
   - `[wsl2]` section present with another value: replace the value in place, keep every other line.
   - `[wsl2]` section absent: append the section and key.
   - A changed file triggers `wsl --shutdown` so the setting takes effect; an unchanged file does not.

### Stage 3: distro creation

Reuses the lab's download code via `wsl-common.ps1`:

1. Image cache directory `%LOCALAPPDATA%\WSL\images`. Download `SHA256SUMS` from `https://releases.ubuntu.com/26.04.1/`, extract the single entry for `ubuntu-26.04.1-wsl-amd64.wsl`, download the image to `.partial` if not cached, verify SHA256, rename.
2. `wsl --import <Distro> %LOCALAPPDATA%\WSL\<Distro> <image> --version 2`.
3. As root over stdin (`wsl -d <Distro> -u root --cd / --exec bash -s`). `bash -s` executes the first stdin line as script, so the payload is an `IFS= read -r` line, then the password (base64 of its UTF-8 bytes, so the console encoding cannot alter it, decoded by `base64 -d` inside bash), then the script. Commands in the script run under `{ ... } </dev/null` so none can read the rest of the script from stdin:
   - `useradd --create-home --shell /bin/bash --groups sudo <user>` if absent.
   - `chpasswd` from the read value.
   - `/etc/sudoers.d/<user>-dev-setup` with `NOPASSWD:ALL`, mode 440, checked by `visudo -cf`.
   - `/etc/wsl.conf`: `[boot] systemd=true`, `[user] default=<user>`.
   - Marker `/etc/dev-setup-distro` containing `dev-setup v1 <user>`.
4. `wsl --terminate <Distro>` so systemd becomes PID 1 and the default user applies.

### Stage 4: bootstrap

As the new user (`wsl -d <Distro> --cd ~ --exec bash -s`), streamed to the console:

```bash
set -eu
sudo apt-get update
sudo apt-get install -y git
if [ -d nix-config/.git ]; then git -C nix-config pull --ff-only; else git clone --branch "$BRANCH" "$REPO" nix-config; fi
cd nix-config
bash bootstrap.sh [--no-change-shell]
```

Exit code propagates. On success the script prints: open Ubuntu from the Start menu, or run `wsl -d <Distro>`.

### Idempotency and resume

Rerunning the same command after a failure or a closed window resumes:

- Existing `.wslconfig` entry: skipped.
- Distro already registered with the dev-setup marker: Stage 3 is skipped entirely (no new user, no password prompt beyond confirmation). The username is read from the marker for the summary.
- Distro registered without the marker: refused (Stage 0).
- Existing clone: pulled. Existing Nix: `install-nix.sh` already preserves it. Home Manager activation is already repeatable.

Username and password are therefore only ever prompted on a run that will import a new distro.

## dev-reset.ps1

Parameters: `-Distro` (default `Ubuntu`).

1. Refuses to run elevated.
2. Distro must be registered, and `/etc/dev-setup-distro` inside it must exist and start with `dev-setup v1`. Any other distro is refused with the message that dev-reset only removes distributions created by dev-setup.
3. The registry `BasePath` for the distro must equal `%LOCALAPPDATA%\WSL\<Distro>`; otherwise refuse.
4. Prints what will be deleted and requires the user to type the distro name exactly.
5. `wsl --terminate`, `wsl --unregister`, then `Remove-Item -Recurse` on the install directory if anything remains.
6. Leaves `.wslconfig` and the image cache untouched.

The existing lab reset stays in `wsl-lab.ps1` and keeps its own marker; the two never operate on each other's distributions.

## Ubuntu 26.04.1 move

- `wsl-lab.ps1`: `$ImageName = 'ubuntu-26.04.1-wsl-amd64.wsl'`, `$BaseUrl = 'https://releases.ubuntu.com/26.04.1'`, baseline file `ubuntu-26.04-blank.tar`, marker `Ubuntu-Nix-Test blank baseline v2`, verify `VERSION_ID = 26.04`. The old 24.04 baseline files stay on disk and are ignored; `Create` refuses to run while a v2 baseline exists.
- `install-nix.sh` package list (curl, git, python3, xz-utils, ca-certificates) is expected to be unchanged on 26.04. Confirmed by the lab rebuild, not assumed.
- README: tested base is 26.04; install section becomes the one-liner plus a short "what it does" list and the manual path kept for people who already have a distro.

## Shared PowerShell (`scripts/wsl-common.ps1`)

Functions, each with one purpose:

- `Invoke-Wsl [string[]]$WslArgs` — runs `wsl.exe`, throws on non-zero exit.
- `Get-WslDistros` — names, with NUL characters stripped.
- `Get-WslDistroBasePath $Name` — from `HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss`.
- `Get-UbuntuWslImage $Release $ImageName $CacheDir` — download, verify, return path.
- `Import-WslDistro $Name $InstallPath $Image`.
- `Invoke-WslRootScript $Name $Script [$Stdin]` — pipes a bash script (and optional leading stdin line) to `bash -s` as root, throws on failure.
- `Test-UbuntuUsername $Name` — bool.
- `Merge-WslConfigMirrored $Path` — returns `$true` if the file changed.

`wsl-lab.ps1` keeps its fixed `gary` user, its own lab directory under `%USERPROFILE%\WSL\nix-lab`, and its baseline logic; it only swaps its inline download/import/user code for the shared functions.

## Error handling

- `$ErrorActionPreference = 'Stop'` everywhere; every `wsl.exe` call checks `$LASTEXITCODE`.
- Downloads go to `.partial` and are renamed only after checksum success.
- Any failure after import leaves the distro registered with its marker so a rerun resumes; `dev-reset.ps1` is the way to start over.
- Password handling: the plaintext string exists only between the confirmation and the end of Stage 3; the variable is dropped in a `finally` block so it does not survive a failure or an `iex` session. A failure during Stage 3 unregisters the distribution this run imported, so a rerun starts clean.

## Testing

Static:
- `shellcheck` for bash, `PSScriptAnalyzer` (`Invoke-ScriptAnalyzer -Recurse`) for PowerShell, added to the README's local checks.

Unit (Pester, run from Linux via `powershell.exe -File`), covering the pure functions:
- `Test-UbuntuUsername`: accepts `gary`, `dev_user`, `a1`; rejects `Root`, `1abc`, `with space`, `root`, 33-character names.
- `Merge-WslConfigMirrored`: the five cases in Stage 2.4, including this machine's existing file with `networkingMode=Mirrored` producing no change.
- SHA256SUMS parsing: exactly one matching line, otherwise throws.

End to end, on this machine:
1. `dev-setup.ps1 -Distro Ubuntu-DevTest -Branch feat/shared-dev-bootstrap` with a test username; then `bash scripts/check-shared.sh` inside the new distro; then `dev-reset.ps1 -Distro Ubuntu-DevTest`; then rerun `dev-setup.ps1` to prove a clean rerun.
2. Resume: interrupt a run after import, rerun, confirm it skips to Stage 4 without prompting for a password.
3. `python3 scripts/lab.py rebuild` on the 26.04.1 baseline.
4. Results recorded in `assessment/dev-setup-verification.md`.

The last check before merge is a run of the published one-liner against `main` on a machine without the repo cloned.
