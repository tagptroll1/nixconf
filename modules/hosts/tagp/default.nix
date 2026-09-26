{ self, inputs, ... }:
let
  # The name `nixos-rebuild --flake .#<attr>` needs. It is not the host's
  # networking.hostName, so it is handed to the config rather than guessed.
  attr = "tagp";
in
{
  flake.nixosConfigurations.${attr} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.tagpConfiguration
      { omarchy.flakeAttr = attr; }
    ];
  };
}
