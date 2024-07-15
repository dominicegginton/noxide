{ pkgs, lib ? pkgs.lib }:

let
  buildPackage = import ./default.nix { inherit pkgs; };
in

with lib.sources;

{
  empty-package =
    buildPackage {
      name = "empty-package";
      src = cleanSource ./test/empty-package;
      dontNpmBuild = true;
      npmDepsHash = "";

      doCheck = true;
      checkPhase = ''
        if [ ! -f package.json ]; then
          echo "package.json not found in $out"
          exit 1
        fi
      '';
    };

  hello-world = buildPackage {
    name = "hello-world";
    src = cleanSource ./test/hello-world;
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r * $out
      mkdir -p $out/bin
      echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world
      echo "require('../main.js')" >> $out/bin/hello-world
      chmod +x $out/bin/hello-world
    '';

    doCheck = true;
    checkPhase = ''
      if [ ! -f package.json ]; then
        echo "package.json not found in $out"
        exit 1
      fi
    '';
  };

  hello-world-deps = buildPackage {
    name = "hello-world-deps";
    src = cleanSource ./test/hello-world-deps;
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r * $out
      mkdir -p $out/bin
      echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world-deps
      echo "require('../main.js')" >> $out/bin/hello-world-deps
      chmod +x $out/bin/hello-world-deps
    '';

    doCheck = true;
    checkPhase = ''
      if [ ! -f package.json ]; then
        echo "package.json not found in $out"
        exit 1
      fi
    '';
  };

  hello-world-external-deps = buildPackage {
    name = "hello-world-external-deps";
    src = cleanSource ./test/hello-world-external-deps;
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r * $out
      mkdir -p $out/bin
      echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world-external-deps
      echo "require('../main.js')" >> $out/bin/hello-world-external-deps
      chmod +x $out/bin/hello-world-external-deps
    '';

    doCheck = true;
    checkPhase = ''
      if [ ! -f package.json ]; then
        echo "package.json not found in $out"
        exit 1
      fi
    '';
  };

  hello-world-workspaces = buildPackage {
    name = "hello-world-workspaces";
    src = cleanSource ./test/hello-world-workspaces;
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
  };
}
