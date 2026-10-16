# effectcraft - managed by the Packages menu
{
  apps.effectcraft = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # Not in nixpkgs yet.
        home.packages = [
          (pkgs.callPackage ../../pkgs/craft-app.nix { } {
            pname = "effectcraft";
            version = "0.6.0";
            hash = "sha256-O3s4cFkqcQS3+xxby/oY7uqkBLbQsRsPR1xQsw+5FQ8=";
            cargoHash = "sha256-ovareokcWnGDe2GxyZFSfxU/on2Ad3QLnoSTHkswVB4=";
            description = "Motion graphics and visual effects";
            buildInputs = [ pkgs.alsa-lib ];
          })
        ];
      };
  };
}
