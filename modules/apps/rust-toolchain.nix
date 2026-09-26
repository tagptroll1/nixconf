# rust-toolchain - managed by the Packages menu
#
# One row for the whole rust side, rather than five.
{
  apps.rust-toolchain = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          rustc
          cargo
          rust-analyzer
          rustfmt
          clippy
        ];
      };
  };
}
