{
  description = "Build NPM packages in Nix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    (
      flake-utils.lib.eachDefaultSystem
      (
        system: let
          noxide = import ./. {
            pkgs = nixpkgs.legacyPackages."${system}";
          };
        in {
          legacyPackages = {
            inherit
              (noxide)
              buildPackage
              ;
          };

          packages = {
            inherit (noxide)
              empty-package
              hello-world
              hello-world-deps;
          };

          formatter = nixpkgs.legacyPackages.${system}.alejandra;
        }
      )
    )
    // {
      overlays = {
        default = final: prev: {
          noxide = import ./. {
            pkgs = final;
          };
        };
      };
    };
}
