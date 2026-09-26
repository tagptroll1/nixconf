# vscode - managed by the Packages menu
{
  apps.vscode = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { ... }:
      {
        programs.vscode.enable = true;
      };
  };
}
