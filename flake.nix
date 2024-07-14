{
  description = "Build NPM packages in Nix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:

    with flake-utils.lib;
    with nixpkgs.legacyPackages.x86_64-linux;

    let
      systems = nodejs.meta.platforms;
    in

    eachSystem systems
      (system:

        let
          pkgs = import nixpkgs { inherit system; };
          noxide = import ./default.nix { inherit pkgs; lib = pkgs.lib; };
          tests = import ./tests.nix { inherit pkgs; };
        in

        {
          formatter = pkgs.nixpkgs-fmt;
          checks = tests;
          legacyPackages.noxide = noxide;
        }
      )

    //

    {
      overlays.default = final: prev: { inherit noxide; };
    };
}
