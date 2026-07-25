{ self, ... }:
{
  flake.homeModules.chromium =
    { ... }:
    {
      programs.chromium = {
        enable = true;
      };
    };
}
