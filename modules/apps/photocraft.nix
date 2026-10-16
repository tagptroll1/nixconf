# photocraft - managed by the Packages menu
{
  apps.photocraft = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # Not in nixpkgs yet.
        home.packages = [
          (pkgs.callPackage ../../pkgs/craft-app.nix { } {
            pname = "photocraft";
            version = "0.5.0";
            hash = "sha256-Ye8Fv4CPBUtqi1ZAJvXfpvyaXk7Ga9BAwl2nrsLEZWA=";
            cargoHash = "sha256-Id7pMLTkMvW/3/CESTGnWpdVVoF7yJLnbNMTQVt8n3s=";
            description = "Image editor, clean-room Photoshop reimplementation";
            # HEIC import, as upstream release builds.
            buildFeatures = [ "heif" ];
          })
        ];
      };
  };
}
