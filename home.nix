{
  config,
  pkgs,
  ...
}:
let
  mangoPath = "${config.home.homeDirectory}/nixos-dotfiles/config/mango";
  nvimPath = "${config.home.homeDirectory}/nixos-dotfiles/config/nvim";
  waybarPath = "${config.home.homeDirectory}/nixos-dotfiles/config/waybar";
  ghosttyPath = "${config.home.homeDirectory}/nixos-dotfiles/config/ghostty";
  rofiPath = "${config.home.homeDirectory}/nixos-dotfiles/config/rofi";

in
{
  imports = [
    ./mopidy.nix
    ./librewolf.nix
  ];

  home.username = "tagp";
  home.homeDirectory = "/home/tagp";
  home.stateVersion = "26.05";
  programs.git.enable = true;
  programs.bash = {
    enable = true;
  };

  # Cursor theme; without it GTK apps (waybar) fail to load hand2/arrow cursors.
  home.pointerCursor = {
    gtk.enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
  };

  services.easyeffects = {
    enable = true;
    preset = "headset-eq";
    extraPresets = {
      headset-eq = builtins.fromJSON (builtins.readFile ./config/easyeffects/headset-eq.json);
      mic-noise-reduction = builtins.fromJSON (
        builtins.readFile ./config/easyeffects/mic-noise-reduction.json
      );
    };
  };

  home.file.".config/mango".source = config.lib.file.mkOutOfStoreSymlink mangoPath;
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
  home.file.".config/waybar".source = config.lib.file.mkOutOfStoreSymlink waybarPath;
  home.file.".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink ghosttyPath;
  home.file.".config/rofi".source = config.lib.file.mkOutOfStoreSymlink rofiPath;
  home.file.".config/discord/settings.json".source = ./config/discord/settings.json;
}
