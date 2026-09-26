# ponysay - managed by the Packages menu
{
  apps.ponysay = {
    enable = false; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.ponysay ];
      };
  };
}
