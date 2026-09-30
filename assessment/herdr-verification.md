# Herdr verification

Verified in `Ubuntu-Nix-Test` on 2026-09-17.

The configuration installs Herdr 0.7.5 from its official Linux x86-64 release asset. Its SHA-256 checksum is `3dc83288073e4c2d3c679a30e7be97bcca9141c6fd17dbbb9219142e95c59253`, identical to the working Ubuntu binary. Nix verifies that checksum and checks the installed version during the build.

Home Manager supplies the existing settings: onboarding disabled, Zsh, automatic shell mode, working-directory following, and the terminal theme. It also installs generated Zsh completions. Session state, logs, plugins, and credentials were not migrated.

The live test starts a uniquely named session under a temporary configuration directory with inherited Herdr pane and socket settings removed. It checks that the session is not the default and that its socket is inside the temporary directory. A real pane then runs Zsh, verifies Node 22, and prints a marker that the test waits for. The test stops its own session afterward; failure cleanup targets only the server process it created.

The package build, live pane test, and static script checks passed. The test WSL instance was updated in place without a reset. Interactive visual behavior remains for the user to try with `herdr`.
