# opencode - managed by the Packages menu
{ inputs, ... }:
{
  apps.opencode = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        programs.opencode = {
          enable = true;
          # Upstream postInstall still calls the 1.x `completion` subcommand, which 2.0
          # dropped for `--completions`, so the build fails without this.
          package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode.overrideAttrs {
            postInstall = ''
              installShellCompletion --cmd opencode \
                --bash <($out/bin/opencode --completions bash) \
                --zsh <($out/bin/opencode --completions zsh) \
                --fish <($out/bin/opencode --completions fish)
            '';
          };
        };
      };
  };
}
