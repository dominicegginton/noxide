{ pkgs, lib }:

lib.noxide {
  name = "hello-world-deps";
  src = lib.sources.cleanSource ./.;
  dontNpmBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r * $out
    mkdir -p $out/bin
    echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world-deps
    echo "require('../main.js')" >> $out/bin/hello-world-deps
    chmod +x $out/bin/hello-world-deps
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    if [ ! -f package.json ]; then
      echo "package.json not found in $out"
      exit 1
    fi
  '';
}
