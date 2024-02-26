{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.noxide.url = "github:dominicegginton/noxide";

  outputs = {
    self,
    nixpkgs,
    noxide,
  }: let
    version = builtins.substring 0 8 self.lastModifiedDate;
    supportedSystems = ["x86_64-linux" "aarch64-linux" "i686-linux" "x86_64-darwin" "aarch64-darwin"];

    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems (system: f system);

    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
          noxide.overlays.default
        ];
      });
  in {
    overlays = {
      default = final: prev: {
        hello-world = final.noxide.buildPackage ./. {};
      };
    };

    packages = forAllSystems (system: {
      inherit (nixpkgsFor.${system}) hello-world;

      default = self.packages.${system}.hello-world;
    });

    devShells = forAllSystems (system: {
      default = nixpkgsFor.${system}.mkShell {
        buildInputs = with nixpkgsFor.${system}; [nodejs];
      };
    });
  };
}
