# lightcraft - managed by the Packages menu
{
  apps.lightcraft = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # Not in nixpkgs yet.
        home.packages = [
          (pkgs.callPackage ../../pkgs/craft-app.nix { } {
            pname = "lightcraft";
            version = "0.4.0";
            hash = "sha256-6/MxXgVN+1IPj4i/tjpUvP0xAKk22cuY7p6WQraZ1ug=";
            cargoHash = "sha256-Z6r3NGsYyE/bdTzuPFjUba6YsxCl9qieDrICeqFpo/A=";
            description = "Photo library and raw developer";
          })
        ];
      };
  };
}
