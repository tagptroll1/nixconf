# chromium - managed by the Packages menu
{
  apps.chromium = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { ... }:
      {
        programs.chromium.enable = true;
      };
  };
}
