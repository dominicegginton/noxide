[<img src="https://avatars.githubusercontent.com/u/6078720?s=200&v=4" width="100" alt="NPM">](https://npmjs.com)
[<img src="https://nixos.org/logo/nixos-logo-only-hires.png" width="100" alt="NixOS">](https://nixos.org)

# Noxide

> [!CAUTION]
>
> Noxide should be considered unstable.

Support for building npm package in Nix. More information to coming soon ...

## How does Noxide work ?

1. Noxide loads the `package-lock.json` file and parses it. Then it fetches all specified packages into the Nix Store.
2. Noxide uses `npm cache` on the stored packages to allow install to work.
3. Noxide calls all the npm commands.
4. Noxide installs everything automatically or based on what was specified in `installPhase`.

## Documentation

### `noxide.lib.buildNpmPackage`

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.noxide.url = "github:dominicegginton/noxide";
  inputs.noxide.inputs.nixpkgs.follows = "nixpkgs"; # optional but recommended

  outputs = { self, nixpkgs, noxide }:

  {
    packages = {
      my-package = noxide.lib.buildNpmPackage {
        name = "my-package";
        src = ./.;
      };
    };
  };
}
```

### `noxide.overlays.default`

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.noxide.url = "github:dominicegginton/noxide";
  inputs.noxide.inputs.nixpkgs.follows = "nixpkgs"; # optional but recommended

  outputs = { self, nixpkgs, noxide }:

  let
    pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ noxide.overlays.default ];
    };
  in
  {
      packages = {
        my-package = pkgs.lib.buildNpmPackage {
            name = "my-package";
            src = ./.;
        };
      };
  };
}
```
