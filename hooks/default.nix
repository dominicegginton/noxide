{ pkgs, nodejs }:

{
  npmBuildHook = pkgs.makeSetupHook { name = "npm-build-hook"; } ./npm-build-hook.sh;
}
