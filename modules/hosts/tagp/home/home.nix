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
        self.homeModules.slack
        self.homeModules.omarchy
        self.homeModules.opencode
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

      # EasyEffects only applies the EQ to streams it intercepts, and by default it
      # intercepts a subset and pins itself to one output device. Both keys below make
      # "every output is equalized" a rule instead of a coincidence:
      #
      #   processAllOutputs     every output stream is pulled into easyeffects_sink,
      #                         whatever device it asked for
      #   useDefaultOutputDevice easyeffects_sink follows the default sink, so switching
      #                         output from the bar moves the EQ'd audio with it instead
      #                         of leaving it on the old device
      #
      # EasyEffects owns db/easyeffectsrc at runtime and rewrites it on exit, so this
      # cannot be a nix symlink - it is enforced here on every activation and the daemon
      # is restarted to pick it up. Flipping either toggle in the GUI will not survive a
      # rebuild; that is deliberate.
      home.activation.easyeffectsAlwaysEqualize = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        rc="$HOME/.config/easyeffects/db/easyeffectsrc"
        run mkdir -p "$(dirname "$rc")"
        [ -e "$rc" ] || run touch "$rc"

        run ${pkgs.gawk}/bin/awk -v out="$rc.hm-new" '
          BEGIN { want["processAllOutputs"] = "true"; want["useDefaultOutputDevice"] = "true" }
          function flush_blanks(  i) { for (i = 1; i <= nblank; i++) print "" > out; nblank = 0 }
          function close_section(  k) {
            if (section == "StreamOutputs")
              for (k in want) if (!(k in seen)) print k "=" want[k] > out
            flush_blanks()
          }
          /^$/ { nblank++; next }
          /^\[.*\]$/ {
            close_section()
            section = substr($0, 2, length($0) - 2)
            if (section == "StreamOutputs") found = 1
            print > out; nout++
            next
          }
          {
            flush_blanks()
            split($0, kv, "=")
            if (section == "StreamOutputs" && kv[1] in want) { print kv[1] "=" want[kv[1]] > out; seen[kv[1]] = 1 }
            else print > out
            nout++
          }
          END {
            close_section()
            if (!found) {
              if (nout) print "" > out
              print "[StreamOutputs]" > out
              for (k in want) print k "=" want[k] > out
            }
          }
        ' "$rc"
        run mv "$rc.hm-new" "$rc"

        # Only meaningful inside a live session; a rebuild from a TTY has nothing to poke.
        if ${pkgs.systemd}/bin/systemctl --user -q is-active easyeffects.service 2>/dev/null; then
          run ${pkgs.systemd}/bin/systemctl --user restart easyeffects.service
        fi
      '';

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
