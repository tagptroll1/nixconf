# node-toolchain - managed by the Packages menu
#
# pnpm needs a node runtime; also what vite/svelte-kit run on.
{
  apps.node-toolchain = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          nodejs
          pnpm
        ];
        # Nix pnpm can't run the generic-linux pnpm it would download for a pinned packageManager.
        xdg.configFile."pnpm/config.yaml".text = ''
          pmOnFail: warn
        '';
      };
  };
}
