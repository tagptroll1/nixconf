{ self, ... }:
let
  user = "tagp";
in
{
  flake.nixosModules.tagpUser =
    { ... }:
    {
      users.users.${user} = {
        isNormalUser = true;
        description = user;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
      };
      home-manager.users.${user} = self.homeModules.tagpHome;
    };
}
