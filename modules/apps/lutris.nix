# lutris - managed by the Packages menu
#
# Gamemode and the gamescope wrapper come from modules/apps/steam.nix via PATH, so
# Lutris games get the same keymap and clipboard settings as Steam games.
{
  apps.lutris = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, osConfig, ... }:
      {
        programs.lutris = {
          enable = true;
          # A different steam package here would conflict with the running one
          steamPackage = osConfig.programs.steam.package;
          # Lutris can only run Proton through umu
          extraPackages = [ pkgs.umu-launcher ];
          protonPackages = [ pkgs.proton-ge-bin ];
          defaultWinePackage = pkgs.proton-ge-bin;
        };
      };
  };
}
