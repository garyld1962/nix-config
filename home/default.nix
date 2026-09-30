{ pkgs, ... }:
{
  imports = [ ./agentic-tools.nix ];
  home.username = "gary";
  home.homeDirectory = "/home/gary";
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
  ];
  xdg.configFile."herdr/config.toml".source = ./herdr.toml;
  home.sessionVariables = {
    # Project Python environments use the configured interpreter unless explicitly overridden.
    UV_PYTHON_DOWNLOADS = "never";
  };
  home.sessionPath = [ "$HOME/.local/bin" ];
  programs.git.enable = true;
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
    dotDir = "/home/gary";
    enableCompletion = true;
    defaultKeymap = "emacs";
    history = {
      size = 50000;
      save = 50000;
      path = "/home/gary/.zsh_history";
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
