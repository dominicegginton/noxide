[<img src="https://avatars.githubusercontent.com/u/6078720?s=200&v=4" width="100" alt="NPM">](https://npmjs.com)
[<img src="https://nixos.org/logo/nixos-logo-only-hires.png" width="100" alt="NixOS">](https://nixos.org)

# Noxide

> [!CAUTION]
>
> Noxide should be considered unstable.

Support for building npm package in Nix. Think [Napalm](https://github.com/nix-community/napalm) (_big thanks for groundwork_) without the registry.

## How does Noxide work ?

These are general steps that Noxide makes when building packages (if you want to learn more, see source code of `default.nix`):

1. Noxide loads the `package-lock.json` file and parses it. Then it fetches all specified packages into the Nix Store.
2. Noxide uses `npm cache` on the stored packages to allow install to work.
3. Noxide calls all the npm commands.
4. Noxide installs everything automatically or based on what was specified in `installPhase`.

## Building NPM packages in Nix with Noxide

### Basic Noxide usage

Use the `buildPackage` function provided in the [`default.nix`](./default.nix)
for building npm packages (replace `<noxide>` with the path to noxide;
with [niv]: `niv add nmattia/noxide`):

``` nix
let
  noxide = pkgs.callPackage <noxide> {};
in noxide.buildPackage ./. {}
```

> [!NOTE]
> noxide uses the package's `package-lock.json` (or `npm-shrinkwrap.json`) for building a package database.
> Make sure there is either a `package-lock.json` or `npm-shrinkwrap.json` in the source.
> Alternatively provide the path to the package-lock file:

``` nix
let
    noxide = pkgs.callPackage <noxide> {};
in noxide.buildPackage ./. { packageLock = <path/to/package-lock>; }
```

### Noxide with Nix flakes

If you want to use Noxide in your flake project, you can do that by adding it to your inputs and either passing `noxide.overlays.default` to your Nixpkgs instance, or by using the `noxide.legacyPackages` `buildPackage` output. To configure the latter's environment.

#### Example `flake.nix`

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.noxide.url = "github:dominicegginton/noxide";

  # NOTE: This is optional, but is how to configure noxide's env
  inputs.noxide.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, noxide }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages."${system}";
  in {
    # Assuming the flake is in the same directory as package-lock.json
    packages."${system}".package-name = noxide.legacyPackages."${system}".buildPackage ./. { };

    devShells."${system}".shell-name = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [ nodejs ];
    };
  };
}
```

### Handling Complicated Scenarios with Noxide

The examples below assume that you have imported `noxide` in some way.

### Custom NodeJs Version

Noxide makes it quite simple to use custom node.js (with npm) version.
This is controlled via `nodejs` argument.

#### Example 1

Changing node.js version to the one that is supplied in `nixpkgs`:

```nix
{ noxide, nodejs-16_x, ... }:
noxide.buildPackage ./. {
  nodejs = nodejs-16_x;
}
```

#### Example 2

Changing node.js version to some custom version (just an idea):

```nix
{ noxide, nodejs-12_x, ... }:
let
  nodejs = nodejs-12_x.overrideAttrs (old: rec {
    pname = "nodejs";
	version = "12.19.0";
    sha256 = "1qainpkakkl3xip9xz2wbs74g95gvc6125cc05z6vyckqi2iqrrv";
    name = "${pname}-${version}";
    src = builtins.fetchurl {
      inherit sha256;
      url = "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
	};
  });
in
noxide.buildPackage ./. {
  inherit nodejs;
}
```

### Pre/Post NPM Hooks

Noxide allows to specify commands that are run before and after every `npm` call.
These hooks work also for nested `npm` calls thanks to npm override mechanism.

#### Example

Patching some folder with executable scripts containing shebangs (that may be generated by npm script):

```nix
{ noxide, ... }:
noxide.buildPackage ./. {
  postNpmHook = ''
    patchShebangs tools
  '';
}
```
