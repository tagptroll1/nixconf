# obs-studio - managed by the Packages menu
#
# Screen capture goes through the existing pipewire/wlr portal, NVENC through the
# nvidia driver - which needs the runpath fix overlay in
# modules/hosts/tagp/configuration.nix.
{
  apps.obs-studio = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.obs-studio ];
      };
  };
}
