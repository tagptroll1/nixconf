{ self, inputs, ... }:
{
  flake.nixosModules.mangowm =
    { ... }:
    {
      imports = [ inputs.mangowm.nixosModules.mango ];

      programs.mango.enable = true;
    };
}
