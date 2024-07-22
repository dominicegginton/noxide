{ pkgs, lib, fetchurl }:

let
  colors = fetchurl {
    url = "https://registry.npmjs.org/colors/-/colors-1.4.0.tgz";
    hash = "sha512-a+UqTh4kgZg/SlGvfbzDHpgRu7AAQOmmqRHJnxhRZICKFUT91brVhNNt58CMWU9PsBbv3PDCZUHbVxuDiH2mtA==";
  };
in

lib.buildNpmPackageNoxide {
  name = "hello-world-deps-override";
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
  overrideDeps = { colors = colors; };
}
