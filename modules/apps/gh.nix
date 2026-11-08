# gh - managed by the Packages menu
{
  apps.gh = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { ... }:
      {
        programs.gh.enable = true;
      };
  };
}
