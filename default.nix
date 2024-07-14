# The noxide Nix support for building NPM packages.
# See `buildPackage` for the main entry point.

{ pkgs }:

with builtins;
with pkgs.lib;
with pkgs.stdenv;
with pkgs.nodejs;

let
  fallbackPackageName = "build-npm-package";
  fallbackPackageVersion = "0.0.0";

  # Helper Functions
  hasFile = dir: filename:
    if versionAtLeast nixVersion "2.3"
    then pathExists (dir + "/${filename}")
    else hasAttr filename (readDir dir);
  ifNotNull = a: b:
    if a != null
    then a
    else b;
  ifNotEmpty = a: b:
    if a != [ ]
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
    then importJSON (root + "/package.json")
    else trace "WARN: package.json not found in ${toString root}" { };
  readPackageLockJSON = root:
    if hasFile root "package-lock.json"
    then importJSON (root + "/package-lock.json")
    else trace "WARN: package-lock.json not found in ${toString root}" { };

  buildPackage = src: attrs @ { name ? null
                      , pname ? null
                      , version ? null
                      , # Used by noxide to read the `package-lock.json` file.
                        # When not provided, it will be inferred from the src directory.
                        root ? src
                      , # The `nodejs` package to use for building the package.
                        nodejs ? pkgs.nodejs
                      , packageLock ? null
                      , # The set of npm commands to run during the build phase of the package.
                        # The --nodedir=${nodejs}/include/node provides native build inputs for building node-gyp packages.
                        npmCommands ? "npm install --prefer-offline --loglevel=silly --no-fund --nodedir=${nodejs}/include/node"
                      , nativeBuildInputs ? [ ]
                      , # The set of build inputs to use for building the package.
                        buildInputs ? [ ]
                      , installPhase ? null
                      , # The bash script to be called before NPM commands are run.
                        preNpmHook ? ""
                      , # The bash script to be called after NPM commands are run.
                        postNpmHook ? ""
                      , # Custom npmBuildHook
                        npmBuildHook ? null
                      , ...
                      }:


    assert name != null -> (pname == null && version == null); let
      # Remove the attributes that are not needed for the derivation.
      mkDerivationAttrs = removeAttrs attrs [
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
      parsedNpmCommands =
        let
          type = typeOf attrs.npmCommands;
        in
        if attrs ? npmCommands
        then
          (
            if type == "list"
            then concatStringsSep "\n" attrs.npmCommands
            else attrs.npmCommands
          )
        else npmCommands;

      hooks = import ./hooks { inherit pkgs nodejs; };

      actualPackage =
        if hasFile root "package.json"
        then root + "/package.json"
        else null;

      actualPackageLock =
        if attrs ? packageLock
        then attrs.packageLock
        else findPackageLock root;

      actualPackageLockJSON = fromJSON (readFile actualPackageLock);

      # An array of all meaningful dependencies build from the dependencies
      # decalred in the package-lock.json file. Filter out the top-level package,
      # which has an empty name, and all packages that do not have a resolved
      # url or integrity hash.
      deps = attrValues (pipe (actualPackageLockJSON.packages or { }) [
        (filterAttrs (name: dep: name != "" && (dep.resolved or null) != null && (dep.integrity or null) != null))
      ]);

      # An array of all the tarballs that are used to build the package.
      # Each dependency is fetched using the `fetchurl` function and the
      # dependencies resolved url and integrity hash.
      tarballs = map
        (dep:
          pkgs.fetchurl {
            url = dep.resolved;
            hash = dep.integrity;
          })
        deps;

      # The `reformatPackageName` function is used to reformat the package name
      # to be compatible with the Nix package name format. The Nix package name
      # format does not allow for the use of the `@` character in the package name.
      reformatPackageName = pname:
        let
          parts = tail (match "^(@([^/]+)/)?([^/]+)$" pname);
          non-null = filter (x: x != null) parts;
        in
        concatStringsSep "-" non-null;

      packageJSON = readPackageJSON root;

      # If name is not provided, read the package.json to load the
      # package name and version from the source package.json
      resolvedPname = attrs.pname or (packageJSON.name or fallbackPackageName);
      resolvedVersion = attrs.version or (packageJSON.version or fallbackPackageVersion);
      name = attrs.name or "${reformatPackageName resolvedPname}-${resolvedVersion}";

      newBuildInputs = buildInputs ++ [ nodejs pkgs.jq ];

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
        pkgs.runCommand "cacache"
          {
            passAsFile = [ "tarballs" ];
            tarballs = concatLines tarballs;
          }
          ''
            mkdir -p _cacache
            while read -r tarball; do
              echo "adding $tarball to npm cache"
              ${nodejs}/bin/npm cache add --cache . "$tarball"
            done < "$tarballsPath"
            ${pkgs.coreutils}/bin/cp -r _cacache $out
          '';
    in

    nodejs.stdenv.mkDerivation

      (
        mkDerivationAttrs

        //

        {
          inherit name version src;
          nativeBuildInputs = nativeBuildInputs
          ++ [
            nodejs
            (if npmBuildHook != null then npmBuildHook else hooks.npmBuildHook)
            nodejs.python
          ]
          ++ optionals stdenv.isDarwin [ darwin.cctools ];
          buildInputs = newBuildInputs ++ [ nodejs ];

          # The default configure phase to configure the package
          # before building it
          #
          # The `HOME` environment variable is
          # set to the current working directory to ensure that the
          # package is built from the correct source directory.
          #
          # The `PATH` environment variable is set to include the
          # `node_modules/.bin` directory to ensure that the package
          # can find the installed dependencies. The `npmOverrideScript`
          # is also added to the `PATH` to ensure that the `npm` command
          # uses the correct version of `nodejs`.
          #
          # The `CPATH` environment variable is set to include the
          # `nodejs` include directory to ensure that the package can
          # find the `node.h` header file.
          #
          # The `npm_config_cache` environment variable is set to the
          # `.npm` directory to ensure that the npm cache is preserved
          # between builds.
          configurePhase =
            attrs.configurePhase
              or ''
              export HOME=$PWD
              export PATH="${npmOverrideScript}/bin:$PATH"
              export CPATH="${nodejs}/include/node:$CPATH"
              export PATH=$PWD/node_modules/.bin:$PATH
              export npm_config_cache=$PWD/.npm
            '';

          # The default build phase to build the package.
          # Build steps are defined as follows:
          # 1. Run the preBuild hook
          # 2. Set the sourceRoot to the current working directory
          # 3. Copy the npm cache to the .npm directory
          # 4. Run the preNpmHook
          # 5. Run the npm commands
          # 6. Run the postNpmHook
          # 7. Run the postBuild hook
          #
          # The `sourceRoot` is set to the current working directory to ensure
          # that the package is built from the correct source directory.
          #
          # To customise the build phase provide custom attrs:
          # - `npmCommands` list of npm commands to run
          # - `preNpmHook` to run a custom bash script before the npm commands are run
          # - `postNpmHook` to run a custom bash script after the npm commands are run
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

          # The default install phase copies the source directory
          # to the output directory. It is common to override the
          # install phase to perform custom installation steps.
          installPhase =
            attrs.installPhase
              or ''
              runHook preInstall
              mkdir -p $out
              cp -r * $out
              runHook postInstall
            '';

          strictDeps = true;
          dontStrip = attrs.dontStrip or true;
          meta = (attrs.meta or { }) // { platforms = attrs.meta.platforms or nodejs.meta.platforms; };
        }
      );
in

buildPackage
