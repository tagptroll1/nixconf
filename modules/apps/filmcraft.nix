# filmcraft - managed by the Packages menu
{
  apps.filmcraft = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # Not in nixpkgs yet.
        home.packages = [
          (pkgs.callPackage ../../pkgs/craft-app.nix { } {
            pname = "filmcraft";
            version = "0.4.0";
            hash = "sha256-qM8o8rSiiGBif0UePQpn6aAEzqbjIMx3ZRoE3wA1yFI=";
            cargoHash = "sha256-uzDeo+94RAK/flnYgTic167BeYfk2zqwwf/ODbwnok0=";
            description = "Video editor";
            buildInputs = [ pkgs.alsa-lib ];
          })
        ];
      };
  };
}
