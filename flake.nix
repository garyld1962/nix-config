{
  description = "Shared Ubuntu WSL shell and development tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.${system} = {
        gh-axi = pkgs.callPackage ./packages/gh-axi { };
        herdr = pkgs.callPackage ./packages/herdr { };
        tuios = pkgs.callPackage ./packages/tuios { };
        wsl-open = pkgs.callPackage ./packages/wsl-open { };
      };
      homeModules.default = ./home/default.nix;
      homeModules.toolchains = ./home/toolchains.nix;
      lib.mkHomeConfiguration = { username, homeDirectory, extraModules ? [ ] }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./home/default.nix
            { home = { inherit username homeDirectory; }; }
          ] ++ extraModules;
        };
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ nodejs_22 pnpm_10_latest python312 uv ];
      };
    };
}
