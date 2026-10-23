{ config, lib, pkgs, ... }:
{
  imports = [ ./agentic-tools.nix ];
  home.stateVersion = "26.05";
  targets.genericLinux.enable = true;
  targets.genericLinux.gpu.enable = false;
  xdg.enable = true;
  programs.home-manager.enable = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  home.packages = with pkgs; [
    bat tmux curl wget
    nodejs_22 pnpm_10 python312 uv
    unzip zip gnutar gzip bzip2 xz iproute2
    (callPackage ../packages/herdr { })
    (callPackage ../packages/wsl-open { })
    # SoX with the PulseAudio driver so `play`/`rec` reach the WSLg sound server.
    (sox.override { enableLibpulseaudio = true; })
  ];
  xdg.configFile."herdr/config.toml".source = ./herdr.toml;
  home.sessionVariables = {
    # Project Python environments use the configured interpreter unless explicitly overridden.
    UV_PYTHON_DOWNLOADS = "never";
    # Opens links in the Windows default browser under WSL; xdg-open elsewhere.
    BROWSER = "wsl-open";
  };
  home.sessionPath = [ "$HOME/.local/bin" ];
  programs.git.enable = true;
  # A private installer may write identity and preferences here.
  # This file is optional and is never read into the Nix store.
  programs.git.includes = [ { path = "${config.xdg.configHome}/git/personal.inc"; } ];
  programs.bash.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };
  programs.zsh = {
    enable = true;
    dotDir = lib.mkDefault config.home.homeDirectory;
    enableCompletion = true;
    # A multi-user Nix installation may have completion paths owned by its
    # original installer. Skip untrusted paths instead of prompting at startup.
    completionInit = "autoload -U compinit && compinit -i";
    defaultKeymap = "emacs";
    history = {
      size = 50000;
      save = 50000;
      path = "${config.home.homeDirectory}/.zsh_history";
      extended = true;
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
    };
    envExtra = ''
      if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
    '';
    initContent = builtins.readFile ./shell.zsh;
  };
}
