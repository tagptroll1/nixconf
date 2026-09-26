# c-toolchain - managed by the Packages menu
#
# The C-family and zig compilers.
{
  apps.c-toolchain = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, lib, ... }:
      {
        home.packages = with pkgs; [
          gcc
          # gcc and clang both ship bin/cc and bin/cpp, and both already carry
          # priority 10, which home.packages' buildEnv refuses as a tie. One step
          # lower hands the unprefixed names to gcc; clang keeps its own.
          (lib.setPrio 11 clang)
          cl
          zig
        ];
      };
  };
}
