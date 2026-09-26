# cowsay - managed by the Packages menu
{
  apps.cowsay = {
    enable = false; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.cowsay ];
      };
  };
}
