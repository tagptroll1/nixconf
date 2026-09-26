# Registry behind the Packages menu: one file per app under modules/apps/,
# each declaring where it installs and what it contributes. Disabled entries
# contribute nothing, so removing an app keeps its file but drops it from the
# build.
{ lib, config, ... }:
let
  enabled = lib.filterAttrs (_: app: app.enable) config.apps;
  modulesFor =
    scope: lib.mapAttrsToList (_: app: app.module) (lib.filterAttrs (_: app: app.scope == scope) enabled);
in
{
  # Declared at flake-parts top level rather than under `flake.`: `apps` is a
  # reserved flake output and would be read as apps.<system>.<name>.
  options.apps = lib.mkOption {
    default = { };
    description = "Apps managed by the Packages menu.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          # Home unless the app needs a NixOS-level option (programs.steam,
          # services.*, setuid wrappers) or has to exist for root. Overlays and
          # permittedInsecurePackages are build plumbing, not scope: they stay
          # in configuration.nix even when a home-scope app needs them.
          scope = lib.mkOption {
            type = lib.types.enum [
              "system"
              "home"
            ];
            default = "home";
          };
          module = lib.mkOption {
            type = lib.types.unspecified;
            default = { };
          };
        };
      }
    );
  };

  config.flake.nixosModules.apps = {
    imports = modulesFor "system";
  };
  config.flake.homeModules.apps = {
    imports = modulesFor "home";
  };
}
