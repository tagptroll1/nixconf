{ self, ... }:
{
  flake.homeModules.tagpHome =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Need path object reference to the config dir
      configPath = ../../../../config;

      mangoPath = "${config.home.homeDirectory}/nixos-dotfiles/config/mango";
      nvimPath = "${config.home.homeDirectory}/nixos-dotfiles/config/nvim";
      tmuxPath = "${config.home.homeDirectory}/nixos-dotfiles/config/tmux";
      ghosttyPath = "${config.home.homeDirectory}/nixos-dotfiles/config/ghostty";
      idleInhibitPath = "${config.home.homeDirectory}/nixos-dotfiles/config/wayland-pipewire-idle-inhibit";
      obsProfilesPath = "${config.home.homeDirectory}/nixos-dotfiles/config/obs-studio/profiles";
    in
    {
      imports = [
        self.homeModules.omarchy
        self.homeModules.mangoRules
        self.homeModules.apps
      ];

      programs.git = {
        enable = true;
        settings.user = {
          name = "Thomas";
          email = "thomas@yesbutmaybe.no";
        };
      };
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

        settings.${lib.concatStringsSep " " [
          "private private.ybmn.no public public.ybmn.no"
          "home01 10.0.0.69"
          "home02 10.2.0.69"
          "media media.ybmn.no 10.2.10.10"
          "ocr 10.2.10.20"
          "immich 10.2.10.21"
          "jellyfin 10.2.10.22"
          "arr 10.2.20.10"
          "share 10.2.30.10"
        ]} = {
          IdentityFile = "~/.ssh/desktop";
          IdentitiesOnly = true;
        };

        settings."private".HostName = "private.ybmn.no";
        settings."public".HostName = "public.ybmn.no";
        settings."home01".HostName = "10.0.0.69";
        settings."home02".HostName = "10.2.0.69";
        settings."media".HostName = "10.2.10.10";
        settings."ocr".HostName = "10.2.10.20";
        settings."immich".HostName = "10.2.10.21";
        settings."jellyfin".HostName = "10.2.10.22";
        settings."arr".HostName = "10.2.20.10";
        settings."share".HostName = "10.2.30.10";

        # Forgejo on the private VM runs its own ssh server on 2222, so the
        # default port would reach the host's sshd instead.
        settings."git.ybmn.no" = {
          User = "git";
          Port = 2222;
          IdentityFile = "~/.ssh/forgejo";
          IdentitiesOnly = true;
        };
      };

      home.sessionVariables.EDITOR = "nvim";

      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        name = "Adwaita";
        package = pkgs.adwaita-icon-theme;
        size = 24;
      };

      # xdg-desktop-portal and its backends are Requisite=/PartOf=graphical-session.target,
      # which nothing starts under mango and which refuses a manual start. A session target
      # bound to it is the supported way in; config/mango/execonce.conf starts this at login.
      systemd.user.targets.mango-session = {
        Unit = {
          Description = "mango session";
          BindsTo = [ "graphical-session.target" ];
          Wants = [ "graphical-session-pre.target" ];
          After = [ "graphical-session-pre.target" ];
        };
      };

      home.file.".config/mango".source = config.lib.file.mkOutOfStoreSymlink mangoPath;
      home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink nvimPath;
      home.file.".config/tmux".source = config.lib.file.mkOutOfStoreSymlink tmuxPath;
      home.file.".config/ghostty".source = config.lib.file.mkOutOfStoreSymlink ghosttyPath;
      home.file.".config/wayland-pipewire-idle-inhibit".source =
        config.lib.file.mkOutOfStoreSymlink idleInhibitPath;
      # only profiles/ - OBS writes logs, cache and window state into the rest of
      # obs-studio/, and scenes reference absolute paths that don't belong in git.
      home.file.".config/obs-studio/basic/profiles".source =
        config.lib.file.mkOutOfStoreSymlink obsProfilesPath;
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
      home.file.".local/share/applications/blender.desktop".source = (
        configPath + /applications/blender.desktop
      );

      home.stateVersion = "26.05";
    };
}
