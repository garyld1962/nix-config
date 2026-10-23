{ pkgs, ... }:
{
  # Optional language toolchains. Opt in per account with:
  #   echo toolchains >> ~/.config/shared-dev/modules && bash scripts/apply-shared.sh
  # post-install.sh does this for you.
  home.packages = with pkgs; [
    go_1_27
    dotnet-sdk_10
    # rustup manages toolchains under ~/.rustup; gcc supplies the linker it needs.
    rustup
    gcc
    typescript
  ];
  home.sessionVariables = {
    GOPATH = "$HOME/go";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
  };
  # go install, cargo install, and dotnet tool install put binaries here.
  home.sessionPath = [ "$HOME/go/bin" "$HOME/.cargo/bin" "$HOME/.dotnet/tools" ];
}
