{ self, inputs, ... }:
{
  flake.nixosModules.sddm =
    { pkgs, ... }:
    let
      # astronaut copies Background into the store, so sddm (own user) can read it.
      # /home is mode 700, so the wallpaper must come from the store, not Downloads.
      sddm-astronaut = pkgs.sddm-astronaut.override {
        embeddedTheme = "astronaut";
        themeConfig = {
          Background = "${./wallpaper.png}";
          CropBackground = "true";
          FullBlur = "false";
          PartialBlur = "false";
        };
      };
    in
    {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true; # run sddm greeter as wayland session
        package = pkgs.kdePackages.sddm; # qt6 sddm, matches astronaut
        theme = "sddm-astronaut-theme";
        extraPackages = sddm-astronaut.propagatedBuildInputs;
      };

      # theme must sit in sddm's theme search path
      environment.systemPackages = [ sddm-astronaut ];
    };
}
