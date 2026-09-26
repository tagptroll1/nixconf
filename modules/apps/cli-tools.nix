# cli-tools - managed by the Packages menu
#
# Terminal tools that are habit, not infrastructure.
{
  apps.cli-tools = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          tmux
          fzf
          ripgrep
          tree
          lazygit
        ];
      };
  };
}
