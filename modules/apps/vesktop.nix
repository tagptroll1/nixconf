# vesktop - managed by the Packages menu
#
# Its pnpm build dep is flagged insecure; the permit is build plumbing and lives
# in modules/hosts/tagp/configuration.nix.
{
  apps.vesktop = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      let
        configPath = ../../config;
      in
      {
        home.packages = [ pkgs.vesktop ];
        home.file.".config/discord/settings.json".source = (configPath + /discord/settings.json);
      };
  };
}
