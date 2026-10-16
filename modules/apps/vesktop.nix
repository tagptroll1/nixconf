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
        # Vencord built with our userplugins (shell mention shelf).
        vencord = pkgs.vencord.overrideAttrs (old: {
          # preBuild, not postPatch: postPatch feeds the pnpmDeps FOD.
          preBuild = (old.preBuild or "") + ''
            cp -r ${configPath + /vesktop/userplugins} src/userplugins
            chmod -R u+w src/userplugins
          '';
        });
      in
      {
        home.packages = [
          (pkgs.vesktop.override {
            withSystemVencord = true;
            inherit vencord;
          })
        ];
        home.file.".config/discord/settings.json".source = (configPath + /discord/settings.json);
      };
  };
}
