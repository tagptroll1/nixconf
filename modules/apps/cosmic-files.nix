# cosmic-files - managed by the Packages menu
{
  apps.cosmic-files = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # COSMIC file manager, runs standalone outside the COSMIC session
        home.packages = [ pkgs.cosmic-files ];
      };
  };
}
