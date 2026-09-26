{ ... }:
{
  # Window rules that belong to an app rather than to the desktop: an app module
  # declares how its own window should behave, and disabling the app takes the
  # rule with it. ~/.config/mango is an out-of-store symlink to this repo, so a
  # generated file cannot land inside it - it goes beside it, and
  # config/mango/monitors.conf sources it.
  flake.homeModules.mangoRules =
    {
      lib,
      config,
      ...
    }:
    {
      options.mango.windowRules = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "appid:qalculate-gtk,isfloating:1" ];
        description = "windowrule= bodies to hand mango, one per line.";
      };

      config.home.file.".config/mango-apps.conf".text =
        "# Generated from the apps' mango.windowRules - edit the app module, not this file.\n"
        + lib.concatMapStrings (rule: "windowrule=${rule}\n") config.mango.windowRules;
    };
}
