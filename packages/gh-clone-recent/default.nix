{ lib, writeShellApplication, gh, jq, git }:

writeShellApplication {
  name = "gh-clone-recent";
  runtimeInputs = [ gh jq git ];
  text = builtins.readFile ./gh-clone-recent.sh;
  meta = {
    description = "Clone every repo in a GitHub account pushed to in the last N days";
    license = lib.licenses.mit;
    mainProgram = "gh-clone-recent";
  };
}
