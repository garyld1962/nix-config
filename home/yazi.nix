{ ... }:
{
  # Optional terminal file manager. Opt in per account with:
  #   echo yazi >> ~/.config/shared-dev/modules && bash scripts/apply-shared.sh
  # post-install.sh does this for you.
  # The shell integration adds `y`, which changes to the last directory on exit.
  programs.yazi.enable = true;
}
