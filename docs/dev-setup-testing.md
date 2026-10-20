# dev-setup end-to-end test: runbook and handoff

Last full run: 2026-10-20 on the laptop `Lestrade` (Windows 11 Pro 26H2, build 10.0.26300.9711),
branch `feat/shared-dev-bootstrap` at commit `81d8769`. Every step passed after the two fixes
recorded below. Use this document to repeat the test from a clone of this repository.

## What is under test

`dev-setup.ps1` (one-command WSL bootstrap), `dev-check.ps1` (validation) and `dev-reset.ps1`
(removal). All three dot-source `scripts/wsl-common.ps1` from the sibling `scripts` folder, so
run them from the repository root or from a folder that preserves that layout. `dev-setup.ps1`
falls back to fetching `wsl-common.ps1` from the same branch on GitHub when no sibling exists,
which is the path the `irm | iex` one-liner in the README uses.

Target runtime is Windows PowerShell 5.1, not elevated. The scripts refuse an elevated window.

## Ground rules

- Never print, log or store the Linux password. The scripts read it as a SecureString and send
  it to the distribution over stdin, base64-encoded, then clear it.
- Steps 3, 5 and 6 are interactive (username, password twice, `y/N`, and the distribution name
  for reset). Run them in a real console window. They cannot be driven by piping text into
  `powershell.exe`: the `wsl.exe` calls that run before the prompts inherit and drain piped
  stdin, so `Read-Host` sees end-of-file and the script cancels or fails. See "Automation
  gotchas" below.
- Use a dedicated distribution name (`-Distro Ubuntu-DevTest`) so other distributions are never
  touched. dev-reset additionally refuses anything without the dev-setup marker file or outside
  `%LOCALAPPDATA%\WSL`.

## Procedure

Run every command from a normal (not elevated) PowerShell window. Replace the branch as needed.

1. **Baseline.** Confirm the window is not elevated, note the Windows build and `wsl --version`
   (WSL may be absent; that is fine). Record `wsl -l -v` so you know which distributions existed
   before the test.

2. **Scripts.** Either work from a clone, or download `dev-setup.ps1`, `dev-check.ps1`,
   `dev-reset.ps1` and `scripts/wsl-common.ps1` from
   `https://raw.githubusercontent.com/garyld1962/nix-config/<branch>/<path>` into a folder that
   keeps `scripts\wsl-common.ps1` in a `scripts` subfolder. Check the folder was empty first; a
   previous run leaves stale copies behind.

3. **Setup.** Expect 10 to 20 minutes, mostly the Nix build.

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\dev-setup.ps1 -Distro Ubuntu-DevTest -Branch feat/shared-dev-bootstrap
   ```

   Expected: prompts for username and password, a summary, `Proceed? [y/N]`, then
   `wsl --update`, `Enabled mirrored networking in .wslconfig; restarting WSL.` (only if
   `.wslconfig` did not already set it), the image download with a curl progress bar,
   `Importing Ubuntu-DevTest into ...`, apt output, the Nix install and Home Manager activation,
   and finally `Done. Open 'Ubuntu-DevTest' from the Start menu, or run: wsl -d Ubuntu-DevTest`.
   If WSL was not installed it stops after `wsl --install` and asks for a reboot; reboot and run
   the same command again.

   On the first Home Manager activation, two warnings say `.bashrc` and `.profile` are "in the
   way" and will be moved to `*.before-shared-dev`. Those are Ubuntu's `/etc/skel` defaults copied
   by `useradd`; Home Manager backs them up and links its own. Harmless.

4. **Validate.** Non-interactive; takes about a minute.

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\dev-check.ps1 -Distro Ubuntu-DevTest
   ```

   Expected: 23 `PASS:` lines, no `FAIL:`, `All checks passed for 'Ubuntu-DevTest'.`, exit code 0.
   Five checks are on the Windows side (WSL version, `.wslconfig`, registration, marker, install
   path), eleven inside the distribution (default user, systemd, sudo, `wsl.conf`, mirrored
   networking, clone, Nix, nix-daemon, Home Manager zsh, generated profile) and the rest come
   from `scripts/check-shared.sh` (pnpm, uv, Zsh login, agentic CLI, Herdr, Node 22 dev shell).

5. **Resume.** Rerun the exact step 3 command. Expected: no username or password prompt, the
   summary contains `Existing distribution: resuming at the bootstrap stage.`, only `Proceed?`
   is asked, and the bootstrap stage runs again idempotently (`git is already the newest
   version`, `Already up to date.`, `No change so reusing latest profile generation`).

6. **Reset.** Type the distribution name when asked.

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\dev-reset.ps1 -Distro Ubuntu-DevTest
   ```

   Expected: `This deletes the WSL distribution 'Ubuntu-DevTest' and everything inside it:`,
   the path, the confirmation prompt, then `Removed Ubuntu-DevTest.` Afterwards `wsl -l -v`
   must not list it and `%LOCALAPPDATA%\WSL\Ubuntu-DevTest` must be gone.

## Clean restart checklist

dev-reset deliberately leaves the image cache and `.wslconfig` in place. For a true first-run
test remove them as well, otherwise step 3 skips the download and the WSL restart:

- `%LOCALAPPDATA%\WSL\images\` (the `.wsl` image and its `SHA256SUMS`).
- `%USERPROFILE%\.wslconfig`, if it did not exist before the test. Note it applies to every
  distribution on the machine, including docker-desktop.
- The scripts folder, if it was downloaded rather than cloned.

What cannot be undone: `dev-setup` runs `wsl --update`. On 2026-10-20 that moved WSL from
2.7.10 to 3.0.3.

## Results, 2026-10-20

| Step | Result |
| --- | --- |
| 1. Baseline | PASS. Not elevated. WSL 2.7.10 already installed. Only `docker-desktop` registered. |
| 2. Scripts | PASS. Four files, HTTP 200. The folder pre-existed with stale but identical copies. |
| 3. Setup, as published | FAIL at import (error below). No distribution was created. |
| 3. Setup, after fix | PASS. Genuine first run: image download, `.wslconfig`, WSL restart, import, user, bootstrap. |
| 4. Validate | PASS. 23/23, exit code 0. Run twice. |
| 5. Resume | PASS. No prompts, resume line printed, bootstrap idempotent. |
| 6. Reset | PASS. `Removed Ubuntu-DevTest.` Registry and folder clean. |

Error from step 3 on the branch as originally published:

```text
dev-setup.ps1 : Cannot process argument transformation on parameter 'Image'. Cannot convert value to type System.String.
    + CategoryInfo          : InvalidData: (:) [dev-setup.ps1], ParameterBindingArgumentTransformationException
    + FullyQualifiedErrorId : ParameterArgumentTransformationError,dev-setup.ps1
```

Line seen once inside the distribution during step 4, before the second fix:

```text
bash: line 1: ﻿set: command not found
```

## Fixes made (commit 81d8769, `scripts/wsl-common.ps1`)

1. **Import failed on every first run.** `Get-UbuntuWslImage` wrote its "Downloading ..." message
   with `Write-Output`, so when the image was not cached the function returned a two-element
   array and `Import-WslDistro`'s `[string]$Image` could not bind. Machines with a cached image
   never hit it, which is why it went unnoticed. Now `Write-Host`.
2. **Payload BOM on UTF-8 consoles.** Windows PowerShell 5.1 prefixes a pipe into a native
   command with a UTF-8 byte-order mark when the console code page is 65001 (the "Use Unicode
   UTF-8 for worldwide language support" option, or `chcp 65001` in a profile). Neither
   `$OutputEncoding` nor `[Console]::OutputEncoding` prevents it. The first payload line is the
   password read, so the account would have ended up with an empty password. `Invoke-WslBashScript`
   now runs `bash -c 'sed "1s/^\xEF\xBB\xBF//" | bash -s'`. Verified on 5.1 under code pages
   65001 and 437 for the default-user path, the root-with-secret path and exit-code propagation.

The Pester suite in `tests/WslCommon.Tests.ps1` does not cover `Invoke-WslBashScript`, and only
Pester 3.4 was installed on the test laptop, so the suite was not run there.

## Open observations

- [ ] `dev-setup.ps1` without a console fails with `You cannot call a method on a null-valued
      expression` (`Read-Host` returns null, then `.Trim()`). A guard with a clear message would help.
- [ ] `dev-reset.ps1` exits 0 after printing `Cancelled.` Consider a non-zero exit so scripts can tell.
- [ ] The `shared-dev` flake input is a `path:` reference to `~/nix-config`, so its lock hash
      changes on every rerun because `.git` changes. `git+file:` would hash only committed content.
- [ ] Optionally delete the `/etc/skel` copies of `.bashrc` and `.profile` before the first
      Home Manager run to avoid the "in the way" warnings.
- [ ] The `irm | iex` one-liner path (no sibling `wsl-common.ps1`) was not exercised; this run
      used downloaded files with the sibling present.

## Automation gotchas

Recorded so nobody repeats them.

- Piping from PowerShell 7 into `powershell.exe` wraps stdin in CLIXML; `Read-Host` receives
  `#< CLIXML`.
- Piping from cmd or bash delivers the text, but `wsl.exe` calls made before the prompt drain
  stdin, so `Read-Host` still gets end-of-file. The scripts are built for a terminal; use one.
- Invoking `powershell.exe` from PowerShell 7 inherits code page 65001, which is how the BOM bug
  surfaced. A user's default console (437 or 1252) does not show it.
- Invoke-WebRequest in PowerShell 7 hung indefinitely on the second raw GitHub download; `curl.exe`
  with `--max-time` did not.
