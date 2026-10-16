# vectorcraft - managed by the Packages menu
{
  apps.vectorcraft = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # Not in nixpkgs yet.
        home.packages = [
          (pkgs.callPackage ../../pkgs/craft-app.nix { } {
            pname = "vectorcraft";
            version = "0.7.0";
            hash = "sha256-W76TxJHWIfLwFmocahH8MCaWARGJYS6q3YLJNoWb0AI=";
            cargoHash = "sha256-mCTuARKTk/8Dhiefool5VAUlYEM+tSu4tkUTnmlKaLY=";
            description = "Vector illustration app";
          })
        ];
      };
  };
}
