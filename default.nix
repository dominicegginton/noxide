{
  pkgs ? import ./nix {},
  lib ? pkgs.lib,
}: let
  fallbackPackageName = "build-npm-package";
  fallbackPackageVersion = "0.0.0";

  hasFile = dir: filename:
    if lib.versionAtLeast builtins.nixVersion "2.3"
    then builtins.pathExists (dir + "/${filename}")
    else builtins.hasAttr filename (builtins.readDir dir);

  ifNotNull = a: b:
    if a != null
    then a
    else b;
  ifNotEmpty = a: b:
    if a != []
    then a
    else b;

  findPackageLock = root:
    if hasFile root "package-lock.json"
    then root + "/package-lock.json"
    else null;

  readPackageJSON = root:
    if hasFile root "package.json"
    then lib.importJSON (root + "/package.json")
    else builtins.trace "WARN: package.json not found in ${toString root}" {};

  buildPackage = src: attrs @ {
    name ? null,
    pname ? null,
    version ? null,
    root ? src,
    nodejs ? pkgs.nodejs,
    packageLock ? null,
    installCommands ? "npm i",
    buildCommands ? "",
    buildInputs ? [],
    installPhase ? null,
    preNpmHook ? "",
    postNpmHook ? "",
    ...
  }:
    assert name != null -> (pname == null && version == null); let
      mkDerivationAttrs = builtins.removeAttrs attrs [
        "packageLock"
        "installCommands"
        "buildCommands"
        "nodejs"
        "packageLock"
        "preNpmHook"
        "postNpmHook"
      ];

      parsedInstallCommands = let
        type = builtins.typeOf attrs.installCommands;
      in
        if attrs ? installCommands
        then
          (
            if type == "list"
            then builtins.concatStringsSep "\n" attrs.installCommands
            else attrs.installCommands
          )
        else installCommands;

      parsedBuildCommands = let
        type = builtins.typeOf attrs.buildCommands;
      in
        if attrs ? buildCommands
        then
          (
            if type == "list"
            then builtins.concatStringsSep "\n" attrs.buildCommands
            else attrs.buildCommands
          )
        else buildCommands;

      actualPackage =
        if hasFile root "package.json"
        then root + "/package.json"
        else null;

      actualPackageLock =
        if attrs ? packageLock
        then attrs.packageLock
        else findPackageLock root;

      actualPackageLockJSON = builtins.fromJSON (builtins.readFile actualPackageLock);

      deps =
        pkgs.lib.attrValues (removeAttrs actualPackageLockJSON.packages [""]);

      tarballs = map (dep:
        pkgs.fetchurl {
          url = dep.resolved;
          hash = dep.integrity;
        })
      deps;

      reformatPackageName = pname: let
        parts = builtins.tail (builtins.match "^(@([^/]+)/)?([^/]+)$" pname);
        non-null = builtins.filter (x: x != null) parts;
      in
        builtins.concatStringsSep "-" non-null;

      packageJSON = readPackageJSON root;
      resolvedPname = attrs.pname or (packageJSON.name or fallbackPackageName);
      resolvedVersion = attrs.version or (packageJSON.version or fallbackPackageVersion);
      name = attrs.name or "${reformatPackageName resolvedPname}-${resolvedVersion}";
      newBuildInputs = buildInputs ++ [nodejs];
      npmOverrideScript = pkgs.writeShellScriptBin "npm" ''
        source "${pkgs.stdenv}/setup"
        set -e
        ${nodejs}/bin/npm "$@"
        if [[ -d node_modules ]]; then find node_modules -type d -name bin | while read file; do patchShebangs "$file"; done; fi
      '';

      cacache =
        pkgs.runCommand "cacache" {
          passAsFile = ["tarballs"];
          tarballs = pkgs.lib.concatLines tarballs;
        }
        ''
          while read -r tarball; do
            echo "Adding $tarball to cache"
            ${nodejs}/bin/npm cache add --cache . "$tarball"
          done < "$tarballsPath"
          ${pkgs.coreutils}/bin/cp -r _cacache $out
        '';
    in
      pkgs.stdenv.mkDerivation (
        mkDerivationAttrs
        // {
          inherit name src;
          buildInputs = newBuildInputs;
          configurePhase =
            attrs.configurePhase
            or '''';
          buildPhase =
            attrs.buildPhase
            or ''
              export HOME=$PWD
              export PATH="${npmOverrideScript}/bin:$PATH"
              export PATH=$PWD/node_modules/.bin:$PATH
              mkdir -p .npm
              cp -r ${cacache} .npm/_cacache
              ${parsedInstallCommands}
              ${parsedBuildCommands}
            '';
          installPhase =
            attrs.installPhase
            or ''
              mkdir -p $out
              cp -r * $out
            '';
        }
      );
in {
  inherit buildPackage;

  test =
    buildPackage ./test {};
}
