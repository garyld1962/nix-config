{ lib, writeShellApplication, runCommand }:

let
  app = writeShellApplication {
    name = "wsl-open";
    text = builtins.readFile ./wsl-open.sh;
  };
in
runCommand "wsl-open" {
  meta = {
    description = "Open URLs and files with the Windows default handler from WSL";
    license = lib.licenses.mit;
    mainProgram = "wsl-open";
  };
} ''
  mkdir -p "$out/bin"
  for name in wsl-open xdg-open open; do
    ln -s "${app}/bin/wsl-open" "$out/bin/$name"
  done
''
