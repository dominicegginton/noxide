# The noxide Nix support for building NPM packages.
# See `buildPackage` for the main entry point.

{ pkgs, lib, ... }:

with builtins;
with lib;
with pkgs.stdenv;
with pkgs.nodejs;

{ name ? "${args.pname}-${args.version}"
, src ? null
, patches ? [ ]
, nativeBuildInputs ? [ ]
, buildInputs ? [ ]
, npmBuildScript ? "build"
, dontNpmBuild ? false
, npmFlags ? [ ]
, npmInstallFlags ? npmFlags
, npmBuildFlags ? npmFlags
, npmRebuildFlags ? npmFlags
, nodejs ? pkgs.nodejs
, customPatchPackages ? { }
, ...
} @ args:

let
  hasFile = src: filename:
    if versionAtLeast nixVersion "2.3"
    then pathExists (src + "/${filename}")
    else hasAttr filename (readDir src);
  findPackageLock = src:
    if hasFile src "package-lock.json"
    then src + "/package-lock.json"
    else null;
  actualPackageLockJSON = fromJSON (readFile (findPackageLock src));

  deps = attrValues
    (pipe (actualPackageLockJSON.packages or { })
      [ (filterAttrs (name: dep: name != "" && (dep.resolved or null) != null && (dep.integrity or null) != null)) ]);

  tarballs =
    map
      # TODO: custom patch packages
      (dep: if false then customPatchPackages.${dep} else pkgs.fetchurl { url = dep.resolved; hash = dep.integrity; })
      deps;

  # reformatPackageName = pname:
  #   let
  #     parts = tail (match "^(@([^/]+)/)?([^/]+)$" pname);
  #     non-null = filter (x: x != null) parts;
  #   in
  #   concatStringsSep "-" non-null;
  # packageJSON = readPackageJSON root;
  # resolvedPname = attrs.pname or (packageJSON.name or fallbackPackageName);
  # resolvedVersion = attrs.version or (packageJSON.version or fallbackPackageVersion);
  # name = attrs.name or "${reformatPackageName resolvedPname}-${resolvedVersion}";
  npmOverrideScript = pkgs.writeShellScriptBin "npm" ''
    source "${pkgs.stdenv}/setup"
    set -e
    ${nodejs}/bin/npm "$@"
    if [[ -d node_modules ]]; then find node_modules -type d -name bin | while read file; do patchShebangs "$file"; done; fi
  '';
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

nodejs.stdenv.mkDerivation (args // {
  inherit npmBuildScript;

  nativeBuildInputs = nativeBuildInputs ++ [ nodejs nodejs.python ] ++ optionals stdenv.isDarwin [ darwin.cctools ];
  buildInputs = buildInputs ++ [ nodejs ];

  configurePhase =
    args.configurePhase
      or ''
      export HOME=$PWD
      export PATH="${npmOverrideScript}/bin:$PATH"
      export PATH=$PWD/node_modules/.bin:$PATH
      export CPATH="${nodejs}/include/node:$CPATH"
      export LIBRARY_PATH="${nodejs}/lib/node_modules/npm/node_modules/node-gyp/gyp/pylib:$LIBRARY_PATH"
      export npm_config_cache=$PWD/.npm
    '';

  buildPhase =
    args.buildPhase
      or ''
      echo "Executing npmBuildHook"
      runHook preBuild
      ${nodejs}/bin/npm config set cache "$npm_config_cache"
      ${nodejs}/bin/npm config set offline true
      ${nodejs}/bin/npm config set progress false

      ${lib.optionalString (customPatchPackages != { }) ''
        echo "Patching npm packages integrity"
        ${nodejs}/bin/node ${./scripts}/package-lock.mjs
      ''}

      mkdir -p .npm
      cp -r ${cacache} .npm/_cacache
      ${nodejs}/bin/npm ci --ignore-scripts --prefer-offline --nodedir=${nodejs}/include/node ${concatStringsSep " " npmInstallFlags} ${concatStringsSep " " npmRebuildFlags}
      if ! ${boolToString dontNpmBuild}; then
        ${nodejs}/bin/npm run ${npmBuildScript} -- ${concatStringsSep " " npmBuildFlags} ${concatStringsSep " " npmFlags}
      fi
      runHook postBuild
      echo "Finished npmBuildHook"
    '';

  installPhase =
    args.installPhase
      or ''
      runHook preInstall
      mkdir -p $out
      cp -r * $out
      runHook postInstall
    '';


  strictDeps = true;
  dontStrip = args.dontStrip or true;
  meta = (args.meta or { }) // { platforms = args.meta.platforms or nodejs.meta.platforms; };
})
