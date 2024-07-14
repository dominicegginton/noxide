{ pkgs }:

let
  buildPackage = import ./default.nix { inherit pkgs; };
in

{
  empty-package =
    buildPackage ./test/empty-package { };

  hello-world = buildPackage ./test/hello-world {
    installPhase = ''
      mkdir -p $out
      cp -r * $out
      mkdir -p $out/bin
      echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world
      echo "require('../main.js')" >> $out/bin/hello-world
      chmod +x $out/bin/hello-world
    '';
  };

  hello-world-deps = buildPackage ./test/hello-world-deps {
    installPhase = ''
      mkdir -p $out
      cp -r * $out
      mkdir -p $out/bin
      echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world-deps
      echo "require('../main.js')" >> $out/bin/hello-world-deps
      chmod +x $out/bin/hello-world-deps
    '';
  };

  hello-world-external-deps = buildPackage ./test/hello-world-external-deps {
    installPhase = ''
      mkdir -p $out
      cp -r * $out
      mkdir -p $out/bin
      echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world-external-deps
      echo "require('../main.js')" >> $out/bin/hello-world-external-deps
      chmod +x $out/bin/hello-world-external-deps
    '';
  };

  hello-world-workspaces = buildPackage ./test/hello-world-workspaces {
    npmCommands = "npm install --ws";
    installPhase = ''
      mkdir -p $out
      cp -r * $out
      mkdir -p $out/bin
      echo "#!${pkgs.nodejs}/bin/node" > $out/bin/hello-world-workspaces
      echo "require('../hello-world/main.js')" >> $out/bin/hello-world-workspaces
      chmod +x $out/bin/hello-world-workspaces
    '';
  };
}
