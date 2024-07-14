# shellcheck shell=bash

npmInstallHook() {
    echo "Executing npmInstallHook"
    runHook preInstall
    runHook postInstall
    echo "Finished npmInstallHook"
}

if [ -z "${dontNpmInstall-}" ] && [ -z "${installPhase-}" ]; then
    installPhase=npmInstallHook
fi
