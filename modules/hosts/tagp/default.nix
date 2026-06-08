{ self, inputs, ... }:
{
  flake.nixosConfigurations.tagp = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.tagpConfiguration
    ];
  };
}
