{ lib, writeShellApplication, runCommand, wl-clipboard }:

let
  app = writeShellApplication {
    name = "wsl-clip";
    runtimeInputs = [ wl-clipboard ];
    text = builtins.readFile ./wsl-clip.sh;
  };
in
runCommand "wsl-clip" {
  meta = {
    description = "pbcopy and pbpaste for the Windows clipboard from WSL via WSLg";
    license = lib.licenses.mit;
    mainProgram = "pbcopy";
  };
} ''
  mkdir -p "$out/bin"
  for name in pbcopy pbpaste; do
    ln -s "${app}/bin/wsl-clip" "$out/bin/$name"
  done
''
