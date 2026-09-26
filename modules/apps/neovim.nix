# neovim - managed by the Packages menu
#
# The editor plus the language servers and the parser builder its config expects.
# Its own config lives in config/nvim, linked from home.nix.
{
  apps.neovim = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          neovim
          tree-sitter # nvim-treesitter main requires the CLI to build parsers
          marksman # markdown LSP
          qt6.qtdeclarative # qmlls, QML LSP
        ];
      };
  };
}
