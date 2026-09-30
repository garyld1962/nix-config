{ lib, stdenvNoCC, fetchurl, installShellFiles }:

stdenvNoCC.mkDerivation rec {
  pname = "herdr";
  version = "0.7.5";
  src = fetchurl {
    url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/herdr-linux-x86_64";
    hash = "sha256-PcgyiAc+TC08Z5ow576XvMqRQcb9F9u7khkULpXFklM=";
  };
  dontUnpack = true;
  dontStrip = true;
  nativeBuildInputs = [ installShellFiles ];
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/herdr"
    installShellCompletion --cmd herdr \
      --zsh <("$out/bin/herdr" completion zsh)
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    test "$("$out/bin/herdr" --version)" = "herdr ${version}"
  '';
  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    license = lib.licenses.agpl3Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "herdr";
  };
}
