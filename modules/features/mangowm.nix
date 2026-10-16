{ self, inputs, ... }:
{
  flake.nixosModules.mangowm =
    { ... }:
    {
      imports = [ inputs.mangowm.nixosModules.mango ];

      programs.mango.enable = true;
      programs.mango.addLoginEntry = false; # SDDM uses the Quickshell session launcher.
    };
}
