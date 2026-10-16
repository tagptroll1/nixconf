# kdenlive - managed by the Packages menu
{
  apps.kdenlive = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.kdePackages.kdenlive ];
      };
  };
}
