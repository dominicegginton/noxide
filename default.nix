# The noxide Nix support for building NPM packages.
# See `buildPackage` for the main entry point.

{ pkgs
, lib
, stdenv
, fetchurl
, writeShellScriptBin
, runCommand
, nodejs
, darwin
, ...
} @ topLevelArgs:

with builtins;
with lib;

{ name ? "${args.pname}-${args.version}"
, src ? null
, patches ? [ ]
, nativeBuildInputs ? [ ]
, buildInputs ? [ ]
, overrideDeps ? { }
, npmBuildScript ? "build"
, dontNpmBuild ? false
, npmFlags ? [ ]
, npmInstallFlags ? npmFlags
, npmBuildFlags ? npmFlags
, nodejs ? topLevelArgs.nodejs
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

  packageLockJSON = fromJSON (readFile (findPackageLock src));

  deps = attrValues (pipe (packageLockJSON.packages or { }) [
    (filterAttrs (name: dep:
      name != ""
      && (dep.resolved or null) != null
      && (dep.integrity or null) != null
      && (overrideDeps.${strings.removePrefix "node_modules/" name} or null) == null))
  ]);

  tarballs = (map
    (dep:
      fetchurl {
        url = dep.resolved;
        hash = dep.integrity;
      })
    deps ++ (attrValues overrideDeps));


  npmOverrideScript = writeShellScriptBin "npm" ''
    source "${stdenv}/setup"
    set -e
    ${nodejs}/bin/npm "$@"
    if [[ -d node_modules ]]; then find node_modules -type d -name bin | while read file; do patchShebangs "$file"; done; fi
  '';

  cacache =
    runCommand "cacache"
      { passAsFile = [ "tarballs" ]; tarballs = concatLines tarballs; }
      ''
        mkdir -p _cacache
        while read -r tarball; do
          echo "adding $tarball to npm cache"
          ${nodejs}/bin/npm cache add --cache . "$tarball"
        done < "$tarballsPath"
        cp -r _cacache $out
      '';
in

nodejs.stdenv.mkDerivation (removeAttrs args [ "overrideDeps" ] // {
  inherit npmBuildScript;

  nativeBuildInputs = nativeBuildInputs ++ [ nodejs nodejs.python ] ++ optionals stdenv.isDarwin [ darwin.cctools ];
  buildInputs = buildInputs ++ [ nodejs ];

  configurePhase =
    args.configurePhase
      or ''
      export HOME=$PWD
      export PATH="${npmOverrideScript}/bin:$PATH"
      export CPATH="${nodejs}/include/node:$CPATH"
      export PATH="${nodejs}/bin:$PATH"
      export PATH=$PWD/node_modules/.bin:$PATH
      export npm_config_cache=$PWD/.npm
      sourceRoot=$PWD
      mkdir -p .npm
      cp -r ${cacache} .npm/_cacache
      npm install --ignore-scripts --prefer-offline --nodedir=${nodejs}/include/node
    '';

  buildPhase =
    args.buildPhase
      or ''
      sourceRoot=$PWD
      if ! ${boolToString dontNpmBuild}; then
        ${nodejs}/bin/npm run ${npmBuildScript} -- ${concatStringsSep " " npmBuildFlags}
      fi
    '';

  installPhase =
    args.installPhase
      or ''
      mkdir -p $out
      cp -r * $out
    '';

  strictDeps = true;
  dontStrip = args.dontStrip or true;
  meta = (args.meta or { }) // { platforms = args.meta.platforms or nodejs.meta.platforms; };
})
