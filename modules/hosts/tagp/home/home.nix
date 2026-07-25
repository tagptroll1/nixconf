{ self, ... }:
{
  flake.homeModules.tagpHome =
    {
      config,
      pkgs,
      ...
    }:
    let
      # Need path object reference to the config dir
      configPath = ../../../../config;

      mangoPath = "${config.home.homeDirectory}/nixos-dotfiles/config/mango";
      nvimPath = "${config.home.homeDirectory}/nixos-dotfiles/config/nvim";
      tmuxPath = "${config.home.homeDirectory}/nixos-dotfiles/config/tmux";
      waybarPath = "${config.home.homeDirectory}/nixos-dotfiles/config/waybar";
      ghosttyPath = "${config.home.homeDirectory}/nixos-dotfiles/config/ghostty";
      rofiPath = "${config.home.homeDirectory}/nixos-dotfiles/config/rofi";
      idleInhibitPath = "${config.home.homeDirectory}/nixos-dotfiles/config/wayland-pipewire-idle-inhibit";
    in
    {
      imports = [
        self.homeModules.librewolf
        self.homeModules.chromium
        self.homeModules.mopidy
        self.homeModules.winbox
      ];

      programs.git.enable = true;
      programs.bash = {
        enable = true;
        shellAliases.cd = "z";
      };
      programs.fish = {
        enable = true;
        shellAliases.cd = "z";
      };
      programs.zoxide.enable = true;

      services.ssh-agent.enable = true;
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."*".AddKeysToAgent = "yes";
      };

      home.sessionVariables.EDITOR = "nvim";

      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
      };

      services.easyeffects = {
        enable = true;
        preset = "headset-eq";
        extraPresets = {
          headset-eq = builtins.fromJSON (builtins.readFile (configPath + /easyeffects/headset-eq.json));
          mic-noise-reduction = builtins.fromJSON (
            builtins.readFile (configPath + /easyeffects/mic-noise-reduction.json)
          );
        };
      };

      home.file.".config/mango".source = config.lib.file.mkOutOfStoreSymlink mangoPath;
      home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
      home.file.".config/tmux".source = config.lib.file.mkOutOfStoreSymlink tmuxPath;
      home.file.".config/waybar".source = config.lib.file.mkOutOfStoreSymlink waybarPath;
      home.file.".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink ghosttyPath;
      home.file.".config/rofi".source = config.lib.file.mkOutOfStoreSymlink rofiPath;
      home.file.".config/wayland-pipewire-idle-inhibit".source =
        config.lib.file.mkOutOfStoreSymlink idleInhibitPath;
      home.file.".config/discord/settings.json".source = (configPath + /discord/settings.json);
      home.file.".local/share/applications/librewolf.desktop".source = (
        configPath + /applications/override/librewolf.desktop
      );
      home.file.".local/share/applications/shutdown.desktop".source = (
        configPath + /applications/shutdown.desktop
      );

      home.stateVersion = "26.05";
    };
}
