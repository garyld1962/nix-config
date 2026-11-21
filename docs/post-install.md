# Post-install steps

Manual steps for an account after `bootstrap.sh` and `post-install.sh` have run. The shared environment works without any of them.

## 1Password CLI (`op`)

The shared profile does not install `op`. Install it from 1Password's apt repository. This is the command from the [1Password CLI install guide](https://developer.1password.com/docs/cli/get-started/) for Debian and Ubuntu:

```bash
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
  sudo tee /etc/apt/sources.list.d/1password.list && \
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ && \
  curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
  sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol && \
  sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 && \
  curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg && \
  sudo apt update && sudo apt install 1password-cli
```

Check the install:

```bash
op --version
```

### Sign in with a service account token

Inside WSL, `op` cannot use the 1Password desktop app on Windows to sign in. Use a service account token instead. Store it in a file only your account can read. This command prompts for the token without showing it or saving it in shell history:

```bash
mkdir -p ~/.config/1password && chmod 700 ~/.config/1password
bash -c 'umask 077; read -rsp "Service account token: " t; printf "%s\n" "$t" > ~/.config/1password/service-account-token'
```

Check that the token works:

```bash
OP_SERVICE_ACCOUNT_TOKEN=$(<~/.config/1password/service-account-token) op vault list
```

## Secrets pattern

API keys live in a 1Password vault. No key is stored in this repository, in the Nix profile, or in shell configuration files that Home Manager manages.

Each key is a 1Password item of type API Credential named `keys.<provider>`, with the key in the `credential` field. Its address is `op://<vault>/keys.<provider>/credential`.

Keys reach the environment in two ways.

### Loaded in every shell

`refresh-secrets` lives in the private homelab repository, not in this one. It reads the service account token from `~/.config/1password/service-account-token`, fetches each key in its `SECRET_SPECS` list with `op read`, and writes them as `export` lines to `~/.secrets` with mode 600.

```bash
~/repos/homelab/scripts/refresh-secrets
```

The shared Zsh configuration sources `~/.secrets` when the file exists, for interactive and non-interactive shells alike. Open a new terminal after running the script. Without the file, the shell starts normally with no keys.

`~/.secrets` holds the keys in plaintext. Keep it out of backups and repositories, and rerun `refresh-secrets` after rotating a key in 1Password.

To add a key:

1. Create the `keys.<provider>` item in the vault with the key in `credential`.
2. Add a `VAR_NAME|keys.<provider>/credential` line to `SECRET_SPECS` in `refresh-secrets`.
3. Rerun `refresh-secrets` and open a new terminal.

### On demand

To read one key without writing it to disk:

```bash
export OP_SERVICE_ACCOUNT_TOKEN=$(<~/.config/1password/service-account-token)
op read "op://<vault>/keys.<provider>/credential"
```

To give keys to one command only, list them in an env file as `op://` references and run the command through `op run`. The file holds references, not key values, and `op run` needs `OP_SERVICE_ACCOUNT_TOKEN` exported as above:

```bash
# keys.env
ANTHROPIC_API_KEY=op://<vault>/keys.anthropic/credential
```

```bash
op run --env-file keys.env -- <command>
```

## SSH keys and commit signing with 1Password

The 1Password app on Windows can hold your SSH keys and serve them to WSL, so no private key is stored inside the distribution. These steps follow [1Password's WSL integration guide](https://developer.1password.com/docs/ssh/integrations/wsl/). They need 1Password for Windows with its SSH agent turned on and at least one SSH key in your vault.

WSL does not talk to the agent directly. Git and SSH inside WSL call the Windows `ssh.exe`, which uses the agent. The shared shell removes Windows directories from `PATH`, so use the full path to the Windows programs.

Check that WSL can see your keys:

```bash
/mnt/c/Windows/System32/OpenSSH/ssh-add.exe -l
```

The command should list the keys stored in 1Password. Then test a connection. 1Password asks you to approve the request:

```bash
/mnt/c/Windows/System32/OpenSSH/ssh.exe -T git@github.com
```

Point Git at the Windows SSH client. Home Manager owns the main Git configuration file, so write personal settings to `personal.inc`:

```bash
git config --file ~/.config/git/personal.inc core.sshCommand /mnt/c/Windows/System32/OpenSSH/ssh.exe
```

SSH configuration for these connections lives on Windows in `%USERPROFILE%\.ssh\config`, not in `~/.ssh/config` inside WSL.

### Sign commits

1. In the 1Password app on Windows, open the SSH key you want to sign with.
2. Choose **Configure Commit Signing**.
3. Select **Configure for Windows Subsystem for Linux (WSL)**, then **Copy Snippet**.
4. Paste the snippet into `~/.config/git/personal.inc`. 1Password's guide says `~/.gitconfig`; `personal.inc` is the file this environment reserves for personal Git settings.

The snippet sets `gpg.format` to `ssh`, `user.signingkey` to your public key, `commit.gpgsign` to `true`, and `gpg.ssh.program` to 1Password's signing program. Add the same public key to GitHub as a signing key so your commits show as verified.

## Disk space

A weekly timer in the shared profile deletes Nix profile generations older than 14 days and collects garbage. To run it now:

```bash
nix-collect-garbage --delete-older-than 14d
```

Freeing space inside the distribution does not shrink its virtual disk file on Windows. Microsoft's [WSL configuration reference](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) lists an experimental `.wslconfig` setting that makes newly created virtual disks sparse, so they can give space back:

```ini
[experimental]
sparseVhd=true
```
