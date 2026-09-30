{ lib, buildNpmPackage, nodejs_22, makeWrapper, gh, git }:

buildNpmPackage {
  pname = "gh-axi";
  version = "0.1.35";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./package.json ./package-lock.json ];
  };
  nodejs = nodejs_22;
  npmDepsHash = "sha256-9nDOcnVkp6DNChnQIQYDjbLaVDvP+T0t3xYmFN1f3v8=";
  npmFlags = [ "--ignore-scripts" ];
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/libexec" "$out/share/licenses/gh-axi"
    cp -r node_modules "$out/libexec/"
    cp node_modules/gh-axi/LICENSE "$out/share/licenses/gh-axi/"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/gh-axi" \
      --add-flags "$out/libexec/node_modules/gh-axi/dist/bin/gh-axi.js" \
      --prefix PATH : ${lib.makeBinPath [ gh git ]}
    runHook postInstall
  '';

  meta = {
    description = "Agent-oriented wrapper for the GitHub CLI";
    homepage = "https://github.com/kunchenguid/gh-axi";
    license = lib.licenses.mit;
    mainProgram = "gh-axi";
  };
}
