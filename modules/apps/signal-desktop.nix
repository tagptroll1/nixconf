# signal-desktop - managed by the Packages menu
{
  apps.signal-desktop = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.signal-desktop ];
      };
  };
}
