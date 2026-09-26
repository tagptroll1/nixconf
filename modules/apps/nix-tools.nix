# nix-tools - managed by the Packages menu
#
# Language server and formatter for this repo's own language.
{
  apps.nix-tools = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          nixd
          nixfmt
        ];
      };
  };
}
