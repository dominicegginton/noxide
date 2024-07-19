{ pkgs, lib }:

lib.buildNpmPackage {
  name = "empty-package";
  src = lib.sources.cleanSource ./.;
  dontNpmBuild = true;
  npmDepsHash = "";

  doInstallCheck = true;
  installCheckPhase = ''
    if [ ! -f package.json ]; then
      echo "package.json not found in $out"
      exit 1
    fi
  '';
}
