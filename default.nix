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
    npmCommands ? "npm install --loglevel verbose --nodedir=${nodejs}/include/node",
    buildInputs ? [],
    installPhase ? null,
    preNpmHook ? "",
    postNpmHook ? "",
    ...
  }:
    assert name != null -> (pname == null && version == null); let
      mkDerivationAttrs = builtins.removeAttrs attrs [
        "packageLock"
        "npmCommands"
        "nodejs"
        "packageLock"
        "preNpmHook"
        "postNpmHook"
      ];

      parsedNpmCommands = let
        type = builtins.typeOf attrs.npmCommands;
      in
        if attrs ? npmCommands
        then
          (
            if type == "list"
            then builtins.concatStringsSep "\n" attrs.npmCommands
            else attrs.npmCommands
          )
        else npmCommands;

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

      cacache =
        pkgs.runCommand "cacache" {
          passAsFile = ["tarballs"];
          tarballs = pkgs.lib.concatLines tarballs;
        }
        ''
          while read -r tarball; do
            ${nodejs}/bin/npm cache add --cache . "$tarball"
          done < "$tarballsPath"
          ${pkgs.coreutils}/bin/cp -r _cacache $out
        '';

      reformatPackageName = pname: let
        parts = builtins.tail (builtins.match "^(@([^/]+)/)?([^/]+)$" pname);
        non-null = builtins.filter (x: x != null) parts;
      in
        builtins.concatStringsSep "-" non-null;

      packageJSON = readPackageJSON root;
      resolvedPname = attrs.pname or (packageJSON.name or fallbackPackageName);
      resolvedVersion = attrs.version or (packageJSON.version or fallbackPackageVersion);
      name = attrs.name or "${reformatPackageName resolvedPname}-${resolvedVersion}";
      newBuildInputs = buildInputs ++ [pkgs.jq nodejs];
    in
      pkgs.stdenv.mkDerivation (
        mkDerivationAttrs
        // {
          inherit name src;
          buildInputs = newBuildInputs;
          configurePhase =
            attrs.configurePhase
            or ''
              runHook preConfigure
              export HOME=$PWD
              runHook postConfigure
            '';
          buildPhase =
            attrs.buildPhase
            or ''
              runHook preBuild
              ${pkgs.coreutils}/bin/mkdir -p .npm
              ${pkgs.coreutils}/bin/ln -s ${cacache} .npm/_cacache
              ${parsedNpmCommands}
              export PATH=$PATH:$PWD/node_modules/.bin
              runHook postBuild
            '';
          installPhase =
            attrs.installPhase
            or ''
              runHook preInstall
              mkdir -p $out
              cp -r * $out
              runHook postInstall
            '';
        }
      );
in {
  inherit buildPackage;

  test = buildPackage ./test {};
}
