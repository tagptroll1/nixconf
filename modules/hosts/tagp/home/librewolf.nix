{ self, ... }:
{
  flake.homeModules.librewolf =
    { ... }:
    {
      programs.librewolf = {
        enable = true;
        settings = {
          "privacy.clearOnShutdown.history" = false;
          "privacy.clearOnShutdown.cookies" = false;
        };
      };
    };
}
