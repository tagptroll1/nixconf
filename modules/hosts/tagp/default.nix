{ self, inputs, ... }:
{
  flake.nixosConfiguration.tagp = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.tagpConfiguration
    ];
  };
}
