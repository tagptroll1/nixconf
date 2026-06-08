# This allows for homeModules to be merged without conflict
{ lib, ... }:
{
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
    description = "Home-manager modules exposed by this flake.";
  };
}
