# The noxide Nix support for building NPM packages.
# See `buildPackage` for the main entry point.
{
  pkgs ? import ./nix {},
  lib ? pkgs.lib,
}: let
  fallbackPackageName = "build-npm-package";
  fallbackPackageVersion = "0.0.0";

  # Helper Functions
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
  findPackageJson = root:
    if hasFile root "package.json"
    then root + "/package.json"
    else null;
  findPackageLock = root:
    if hasFile root "package-lock.json"
    then root + "/package-lock.json"
    else null;
  readPackageJSON = root:
    if hasFile root "package.json"
    then lib.importJSON (root + "/package.json")
    else builtins.trace "WARN: package.json not found in ${toString root}" {};
  readPackageLockJSON = root:
    if hasFile root "package-lock.json"
    then lib.importJSON (root + "/package-lock.json")
    else builtins.trace "WARN: package-lock.json not found in ${toString root}" {};

  # Build NPM Package
  buildPackage = src: attrs @ {
    name ? null,
    pname ? null,
    version ? null,
    # Used by noxide to read the `package-lock.json` file.
    # When not provided, it will be inferred from the src directory.
    root ? src,
    # The `nodejs` package to use for building the package.
    nodejs ? pkgs.nodejs,
    packageLock ? null,
    # The set of npm commands to run during the build phase of the package.
    # The --nodedir=${nodejs}/include/node provides native build inputs for building node-gyp packages.
    npmCommands ? "npm install --loglevel=verbose --no-fund --nodedir=${nodejs}/include/node",
    # The set of build inputs to use for building the package.
    buildInputs ? [],
    installPhase ? null,
    # The bash script to be called before NPM commands are run.
    preNpmHook ? "",
    # The bash script to be called after NPM commands are run.
    postNpmHook ? "",
    ...
  }:
    assert name != null -> (pname == null && version == null); let
      # Remove the attributes that are not needed for the derivation.
      mkDerivationAttrs = builtins.removeAttrs attrs [
        "packageLock"
        "npmCommands"
        "nodejs"
        "packageLock"
        "preNpmHook"
        "postNpmHook"
      ];

      # Parse the `npmCommands` attribute. If it is a list, then
      # concatenate the commands into a single string. Otherwise,
      # use the string as is. If the `npmCommands` attribute is not
      # provided, then use the default value.
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

      actualPackage =
        if hasFile root "package.json"
        then root + "/package.json"
        else null;

      actualPackageLock =
        if attrs ? packageLock
        then attrs.packageLock
        else findPackageLock root;

      actualPackageLockJSON = builtins.fromJSON (builtins.readFile actualPackageLock);

      # An array of all meaningful dependencies build from the dependencies
      # decalred in the package-lock.json file. Filter out the top-level package,
      # which has an empty name, and linked packages.
      deps = pkgs.lib.attrValues (lib.pipe (actualPackageLockJSON.packages or {}) [
        (lib.filterAttrs (name: _: name != ""))
        (lib.filterAttrs (_name: dep: !(dep.link or false)))
      ]);

      # An array of all the tarballs that are used to build the package.
      # Each dependency is fetched using the `fetchurl` function and the
      # dependencies resolved url and integrity hash.
      tarballs = map (dep:
        pkgs.fetchurl {
          url = dep.resolved;
          hash = dep.integrity;
        })
      deps;

      # The `reformatPackageName` function is used to reformat the package name
      # to be compatible with the Nix package name format. The Nix package name
      # format does not allow for the use of the `@` character in the package name.
      reformatPackageName = pname: let
        parts = builtins.tail (builtins.match "^(@([^/]+)/)?([^/]+)$" pname);
        non-null = builtins.filter (x: x != null) parts;
      in
        builtins.concatStringsSep "-" non-null;

      packageJSON = readPackageJSON root;

      # If name is not provided, read the package.json to load the
      # package name and version from the source package.json
      resolvedPname = attrs.pname or (packageJSON.name or fallbackPackageName);
      resolvedVersion = attrs.version or (packageJSON.version or fallbackPackageVersion);
      name = attrs.name or "${reformatPackageName resolvedPname}-${resolvedVersion}";

      newBuildInputs = buildInputs ++ [nodejs];

      # The `npm` command is overridden to use the `nodejs` package
      # for running the `npm` command. This is necessary to ensure
      # that the `npm` command uses the correct version of `nodejs`.
      npmOverrideScript = pkgs.writeShellScriptBin "npm" ''
        source "${pkgs.stdenv}/setup"
        set -e
        ${nodejs}/bin/npm "$@"
        if [[ -d node_modules ]]; then find node_modules -type d -name bin | while read file; do patchShebangs "$file"; done; fi
      '';

      # The `cacache` directory is used to store the npm cache for the
      # package. This is necessary to ensure that the npm cache is
      # preserved between builds.
      cacache =
        pkgs.runCommand "cacache" {
          passAsFile = ["tarballs"];
          tarballs = pkgs.lib.concatLines tarballs;
        }
        ''
          while read -r tarball; do
            echo "adding $tarball to npm cache"
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
            or ''
              export HOME=$PWD
              export PATH="${npmOverrideScript}/bin:$PATH"
              export CPATH="${nodejs}/include/node:$CPATH"
              export PATH=$PWD/node_modules/.bin:$PATH
              export npm_config_cache=$PWD/.npm
            '';

          buildPhase =
            attrs.buildPhase
            or ''
              runHook preBuild

              sourceRoot=$PWD

              echo "copying npm cache"
              mkdir -p .npm
              cp -r ${cacache} .npm/_cacache

              echo "running pre npm hook"
              ${preNpmHook}

              echo "running npm commands"
              ${parsedNpmCommands}

              echo "running post npm hook"
              ${postNpmHook}

              runHook postBuild
            '';

          installPhase =
            attrs.installPhase
            or ''
              runHook preInstall

              echo "copying src to out"
              mkdir -p $out
              cp -r * $out

              runHook postInstall
            '';
        }
      );
in {
  inherit buildPackage;

  test =
    buildPackage ./test {};
}
