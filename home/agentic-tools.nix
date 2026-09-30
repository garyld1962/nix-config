{ pkgs, ... }:
{
  # Matches savviety-skills/bin/install-agentic-tools, with Nix owning every package.
  home.packages = with pkgs; [
    ripgrep fd jq rsync shellcheck ast-grep sd gh just hyperfine xh defuddle
    (callPackage ../packages/gh-axi { })
  ];
}
