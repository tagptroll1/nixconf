{ self, ... }:
let
  user = "tagp";
in
{
  flake.nixosModules.tagpUser =
    { pkgs, ... }:
    {
      programs.fish.enable = true;
      users.users.${user} = {
        isNormalUser = true;
        description = user;
        shell = pkgs.fish;
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
      };
      home-manager.users.${user} = self.homeModules.tagpHome;
    };
}
