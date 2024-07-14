# shellcheck shell=bash

npmBuildHook() {
    echo "Executing npmBuildHook"
    runHook preBuild
    runHook postBuild
    echo "Finished npmBuildHook"
}

if [ -z "${dontNpmBuild-}" ] && [ -z "${buildPhase-}" ]; then
    buildPhase=npmBuildHook
fi
