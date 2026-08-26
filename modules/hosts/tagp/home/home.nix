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
      obsProfilesPath = "${config.home.homeDirectory}/nixos-dotfiles/config/obs-studio/profiles";
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

        # Forgejo on the private VM runs its own ssh server on 2222, so the
        # default port would reach the host's sshd instead.
        matchBlocks."git.ybmn.no" = {
          user = "git";
          port = 2222;
          identityFile = "~/.ssh/forgejo";
          identitiesOnly = true;
        };
      };

      home.sessionVariables.EDITOR = "nvim";

      # so opening a video from cosmic-files lands in mpv
      xdg.mimeApps = {
        enable = true;
        defaultApplications =
          let
            mpv = [ "mpv.desktop" ];
          in
          {
            "video/mp4" = mpv;
            "video/x-matroska" = mpv;
            "video/webm" = mpv;
            "video/quicktime" = mpv;
            "video/x-msvideo" = mpv;
            "video/mpeg" = mpv;
          };
      };

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
      # only profiles/ - OBS writes logs, cache and window state into the rest of
      # obs-studio/, and scenes reference absolute paths that don't belong in git.
      home.file.".config/obs-studio/basic/profiles".source =
        config.lib.file.mkOutOfStoreSymlink obsProfilesPath;
      home.file.".config/discord/settings.json".source = (configPath + /discord/settings.json);
      # bwrap-sandboxed apps (steam-run, epsxe) tmpfs over /etc and don't bind /etc/pipewire,
      # so the /etc/pipewire/client.conf.d override never reaches them; ~/.config/pipewire is
      # visible since bwrap fully binds /home. Same fix, reachable from inside the sandbox.
      home.file.".config/pipewire/client.conf.d/10-disable-rtportal.conf".text = builtins.toJSON {
        "context.properties" = {
          "module.rt" = false;
        };
        "context.modules" = [
          {
            name = "libpipewire-module-rt";
            args = {
              "rtportal.enabled" = false;
              "rtkit.enabled" = true;
            };
            flags = [
              "ifexists"
              "nofail"
            ];
          }
        ];
      };
      home.file.".local/share/applications/librewolf.desktop".source = (
        configPath + /applications/override/librewolf.desktop
      );
      home.file.".local/share/applications/shutdown.desktop".source = (
        configPath + /applications/shutdown.desktop
      );
      home.file.".local/share/applications/blender.desktop".source = (
        configPath + /applications/blender.desktop
      );

      home.stateVersion = "26.05";
    };
}
