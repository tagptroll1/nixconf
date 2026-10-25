# opencode - managed by the Packages menu
{
  apps.opencode = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        programs.opencode = {
          enable = true;
          package = pkgs.opencode.overrideAttrs (old: {
            # Follow Ghostty's live Omarchy palette even when cli.json selects another theme.
            postInstall = old.postInstall + ''
              wrapProgram $out/bin/opencode \
                --set OPENCODE_CLI_CONFIG_CONTENT '{"theme":{"name":"system","mode":"system"}}'
            '';
          });
        };
      };
  };
}
