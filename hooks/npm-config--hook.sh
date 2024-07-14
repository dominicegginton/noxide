# shellcheck shell=bash

npmConfigHook() {
  echo "Executing npmConfigHook"
  echo "Finished npmConfigHook"
}

postPatchHooks+=(npmConfigHook)
