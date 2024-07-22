{ pkgs, lib }:

lib.buildNpmPackageNoxide {
  name = "hello-world";
  src = lib.sources.cleanSource ./.;
  dontNpmBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r * $out
    mkdir -p $out/bin
    echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world
    echo "require('../main.js')" >> $out/bin/hello-world
    chmod +x $out/bin/hello-world
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    if [ ! -f package.json ]; then
      echo "package.json not found in $out"
      exit 1
    fi
  '';
}
