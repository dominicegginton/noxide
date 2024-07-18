{
  description = "Build NPM packages in Nix";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nix-github-actions.url = "github:nix-community/nix-github-actions";
  inputs.nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, nix-github-actions }:

    with nixpkgs.lib;
    with flake-utils.lib;
    with nix-github-actions.lib;

    eachSystem nixpkgs.legacyPackages.x86_64-linux.nodejs.meta.platforms
      (system:

        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in

        {
          formatter = pkgs.nixpkgs-fmt;
          lib.noxide = pkgs.lib.noxide;
          checks = {
            empty-package = pkgs.callPackage ./test/empty-package { };
            hello-world = pkgs.callPackage ./test/hello-world { };
            hello-world-deps = pkgs.callPackage ./test/hello-world-deps { };
            # hello-world-deps-override = pkgs.callPackage ./test/hello-world-deps-override { };
            hello-world-external-deps = pkgs.callPackage ./test/hello-world-external-deps { };
            hello-world-workspaces = pkgs.callPackage ./test/hello-world-workspaces { };
          };
        }
      )

    //

    {
      overlays.default = final: prev: { lib = prev.lib // { noxide = final.callPackage ./default.nix { }; }; };
      githubActions = mkGithubMatrix { checks = getAttrs (attrNames githubPlatforms) self.checks; };
    };
}
