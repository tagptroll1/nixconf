# fastfetch - managed by the Packages menu
{
  apps.fastfetch = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.fastfetch ];
      };
  };
}
