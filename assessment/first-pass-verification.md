# First migration pass verification

Verified on 2026-09-17 in `Ubuntu-Nix-Test`.

The configuration installs the selected shell tools, Node 22, pnpm 10, Python 3.12, and uv. It carries over the portable shell helpers and Starship settings reviewed in the working Ubuntu. Nix manages Node versions in the test instance; NVM is not installed there.

| Check | Result |
| --- | --- |
| Build and activation | Home Manager configuration built and activated successfully. Stock Ubuntu shell files were backed up. |
| Repeated application | Applying the same configuration again produced the same activation store path. |
| Full reset and rebuild | Restored the blank baseline, installed Nix again, reapplied the saved configuration, and reran the smoke tests successfully. |
| Reproducible configuration | The activation store path was identical before and after reset; source and test lock files were identical and the saved lock hash was unchanged. |
| Clean shell | Zsh started with a minimal environment. All selected commands resolved into the Nix store. History, completion, helpers, direnv, Git, and prompt checks passed. |
| Node and pnpm | A small project installed without dependencies in offline mode and ran its Node assertion through pnpm. |
| Python and uv | uv created a virtual environment offline using the Nix-provided Python 3.12 interpreter; execution inside that environment passed. |
| Project environment | `nix develop` launched Node 22 using the same pinned inputs. |
| Restart | After terminating and restarting only the test instance, normal WSL command launch found Node 22.23.2 and the Nix daemon socket was active. |
| Static checks | ShellCheck, Zsh syntax checks, and Python compilation passed. |

Installed runtime versions: Node 22.23.2, pnpm 10.34.0, Python 3.12.14, and uv 0.11.21. [Build evidence](first-pass-build.json) records dependency revisions, the lock hash, and the matching activation paths.

These checks cover the initial toolset and small representative workflows. They do not establish compatibility with every existing project or with native Node/Python dependencies. Docker, GPU support, browser automation, AI tools, credentials, Git identity, and application data remain outside this pass. The working Ubuntu remains the default distribution and retains its existing NVM setup.

The configuration and evidence are local files; nothing has been committed or published.
