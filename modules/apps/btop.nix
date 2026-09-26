# btop - managed by the Packages menu
{
  apps.btop = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.btop ];
      };
  };
}
