# Blank WSL baseline verification

Verified on 2026-09-11 with `scripts/test-wsl-reset.ps1`.

| Check | Result |
| --- | --- |
| Image download | Ubuntu 24.04.5 AMD64 WSL image matched Canonical's SHA-256 checksum. |
| Baseline | Exported outside the test distribution; checksum recorded and checked before reset. |
| Reset | Created `/home/gary/reset-probe`, verified its presence, unregistered only `Ubuntu-Nix-Test`, then imported the baseline. |
| Restored filesystem | Probe absent; baseline marker present. |
| Restored OS | Ubuntu 24.04.5 LTS; `VERSION_ID=24.04`. |
| Default user | `gary`. |
| Service manager | systemd is PID 1. |
| Nix | Not installed. |
| Working distribution | Original `Ubuntu` registry identifier and disk path preserved. |
| WSL default | Unchanged; final listing marks `Ubuntu` as default. |

The first setup attempt stopped during verification because PowerShell argument handling and a final input line ending affected shell execution. The script now passes shell checks over standard input with an explicit final newline and exit command. Setup and the full reset test subsequently passed.

WSL reported that sparse VHD support was disabled. Import succeeded using its normal disk behavior. No unsafe sparse-disk option was enabled. A terminal-size warning appeared during the process check; the systemd assertion passed.

These checks establish a working blank baseline and reset cycle. They do not validate a Nix installation, migrated tools, application data recovery, or isolation from Windows files.
