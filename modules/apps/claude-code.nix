# claude-code - managed by the Packages menu
{
  apps.claude-code = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.claude-code ];
      };
  };
}
