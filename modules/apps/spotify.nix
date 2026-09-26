# spotify - managed by the Packages menu
{
  apps.spotify = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.spotify ];
      };
  };
}
