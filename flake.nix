{
  description = "My main baby";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    awww.url = "git+https://codeberg.org/LGFae/awww";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
  #  {
  #    nixpkgs,
  #    home-manager,
  #    mangowm,
  #    ...
  #  }@inputs:
  #  let
  #    inherit (nixpkgs) lib;
  #
  #  in
  #  {
  #    nixosConfigurations.nixos = lib.nixosSystem {
  #      system = "x86_64-linux";
  #      specialArgs = { inherit inputs; };
  #      modules = [
  #        ./configuration.nix
  #        home-manager.nixosModules.home-manager
  #        {
  #          home-manager = {
  #            useGlobalPkgs = true;
  #            useUserPackages = true;
  #            users.tagp = import ./home.nix;
  #          };
  #        }
  #        mangowm.nixosModules.mango
  #      ];
  #    };
  #  };

}
