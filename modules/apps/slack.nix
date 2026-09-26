# slack - managed by the Packages menu
{
  apps.slack = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # unfree; allowUnfree is set in configuration.nix. Wayland comes from
        # NIXOS_OZONE_WL, exported in config/mango/config.conf.
        home.packages = [ pkgs.slack ];
      };
  };
}
