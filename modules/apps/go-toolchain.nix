# go-toolchain - managed by the Packages menu
#
# Compiler plus its language server.
{
  apps.go-toolchain = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          go
          gopls
        ];
      };
  };
}
