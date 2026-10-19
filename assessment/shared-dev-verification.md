# Shared developer bootstrap verification

Verified on 2026-10-01 in the disposable `Ubuntu-Nix-Test` distribution.

The shared configuration derives the developer's username and home directory rather than using a fixed account. The master `bootstrap.sh` installs Nix when absent, then builds and activates that account's shared Home Manager profile. Personal setup runs separately.

| Check | Result |
| --- | --- |
| Existing lab | Shared profile built, activated, and passed the original smoke tests. |
| Fresh developer account | `nix-trainee` ran the master installer from `/home/nix-trainee/shared dev`, then passed the shell, runtime, agent utility, Herdr, and project environment tests. |
| Personal separation | The fresh account initially had no Git identity. Synthetic personal Git and shell files loaded correctly and survived shared reapplication. |
| Login shell option | `--no-change-shell` retained Bash as the test account's login shell. |
| Full reset and rebuild | Restored the marked blank baseline, confirmed Nix was absent, ran the master installer, and passed all smoke tests. |
| Reproducibility | Activation paths matched across reset. The Nix and npm dependency locks were unchanged. Final source also produced the same activation on repeated application. |
| Local checks | ShellCheck, Zsh syntax checks, Python compilation, seven unit tests, and the secret scan passed. |
| Invocation guards | Root and non-WSL invocations were rejected before installation. A manually maintained profile and a missing shared lock file were rejected by the profile generator. |

Fresh-account testing exposed a sudo validation prompt and a completion trust prompt. The installer validates sudo with an actual command. Zsh skips completion directories it considers insecure. A typed Nix path input supports a source directory containing spaces.

The reset comparison covers the source before a duplicate weather-helper help line was removed. The final source was then applied twice and smoke-tested. [Build evidence](shared-dev-build.json) records both activation comparisons and the unchanged lock hashes.

These checks cover x86-64 Ubuntu 24.04 WSL with systemd. They do not cover ARM, other distributions, authenticated GitHub operations, a private personal installer, or compatibility with every existing project. The fresh test account was removed by restoring the disposable baseline. The working Ubuntu was not used as an installation target.
