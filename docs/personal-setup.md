# Personal setup contract

A developer first runs the shared bootstrap. A separate private installer can then add identities, authentication, secret access, and personal preferences. The shared bootstrap never runs the private installer.

## Git identity and preferences

The managed Git configuration includes `$HOME/.config/git/personal.inc`. This file is optional and is not managed by Home Manager. A private installer can create its directory and write settings with Git:

```bash
mkdir -p "$HOME/.config/git"
git config --file "$HOME/.config/git/personal.inc" user.name 'Your name'
git config --file "$HOME/.config/git/personal.inc" user.email 'you@example.com'
```

Keep tokens and credentials in the appropriate credential provider. The identity include is for settings, not secret storage.

## Personal shell configuration

Zsh loads `$HOME/.config/zsh/local.zsh` when it exists. A private installer can use it for personal aliases, environment preferences, and integration with a secret loader. Reapplying the shared configuration leaves it in place.

Do not put plaintext secrets in shell configuration. Load them through the developer's own secret provider at runtime. 1Password access, vault names, and personal identities belong in the private installer rather than the shared environment.

## Additional packages and Home Manager settings

For a fully managed personal profile, a private flake can call the shared configuration factory and supply extra modules:

```nix
shared-dev.lib.mkHomeConfiguration {
  username = "your-linux-user";
  homeDirectory = "/home/your-linux-user";
  extraModules = [ ./personal.nix ];
}
```

The shared module is also exposed as `homeModules.default` for an existing Home Manager setup. Private overrides may use normal Home Manager options; use `lib.mkForce` when replacing a shared value. Keep secret values out of these modules: Nix build outputs are not a secret store.

The generated `~/.config/shared-dev` profile is reserved for the shared installer. Keep a manually maintained personal flake elsewhere. Activate the personal profile after shared updates so its additional managed settings remain applied.

## Installation boundaries

The shared installer owns the base tool set, shell defaults, and generated user profile. A private installer owns personal files, authentication, optional personal packages, and secret-provider integration. Ubuntu owns the underlying operating system and services.

A fresh developer account must be able to install and use the shared environment without access to any private installer or vault.
