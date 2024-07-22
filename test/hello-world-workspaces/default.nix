{ pkgs, lib }:

lib.buildNpmPackageNoxide {
  name = "hello-world-workspaces";
  src = lib.sources.cleanSource ./.;
  dontNpmBuild = true;
  npmInstallFlags = [ "--ws" ];
  installPhase = ''
    mkdir -p $out
    cp -r * $out
    mkdir -p $out/bin
    echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world-workspaces
    echo "require('../hello-world/main.js')" >> $out/bin/hello-world-workspaces
    chmod +x $out/bin/hello-world-workspaces
  '';

  doCheck = true;
  checkPhase = ''
    if [ ! -f package.json ]; then
      echo "package.json not found in $out"
      exit 1
    fi
  '';
}
