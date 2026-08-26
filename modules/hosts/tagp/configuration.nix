{ self, inputs, ... }:
let
  host = "nixos";
in
{
  flake.nixosModules.tagpConfiguration =
    {
      pkgs,
      config,
      ...
    }:
    {
      imports = [
        self.nixosModules.tagpHardware
        self.nixosModules.tagpUser
        self.nixosModules.mangowm
        self.nixosModules.homeManager
        self.nixosModules.steam
        self.nixosModules.fonts
        self.nixosModules.sddm
      ];

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.timeout = 0; # skip menu; hold Space at boot to show it
      boot.kernelPackages = pkgs.linuxPackages_latest;

      networking.hostName = host;
      networking.networkmanager.enable = true;

      time.timeZone = "Europe/Oslo";

      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "nb_NO.UTF-8";
        LC_IDENTIFICATION = "nb_NO.UTF-8";
        LC_MEASUREMENT = "nb_NO.UTF-8";
        LC_MONETARY = "nb_NO.UTF-8";
        LC_NAME = "nb_NO.UTF-8";
        LC_NUMERIC = "nb_NO.UTF-8";
        LC_PAPER = "nb_NO.UTF-8";
        LC_TELEPHONE = "nb_NO.UTF-8";
        LC_TIME = "nb_NO.UTF-8";
      };

      services.xserver.videoDrivers = [ "nvidia" ];
      services.xserver.xkb = {
        layout = "no";
        variant = "nodeadkeys";
      };
      console.keyMap = "no";

      # Disks
      fileSystems."/mnt/bigboi" = {
        device = "/dev/disk/by-uuid/b5ed953a-a15e-4265-86ea-e2c0d953a632";
        fsType = "ext4";
        options = [
          "defaults"
          "nofail"
        ];
      };

      # Bluetooth & PS4 controller
      hardware.bluetooth.enable = true;
      hardware.bluetooth.package = pkgs.bluez;
      boot.kernelModules = [ "hidp" ]; # BT HID profile; autoload unreliable, DS4 won't connect without it

      # Audio
      security.rtkit.enable = true;
      services.pulseaudio.enable = false;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
        # ALC4080 (onboard analog, USB-attached) glitches on the S32LE altsetting
        # pipewire picks by default; S16_LE altsetting is clean.
        wireplumber.extraConfig."51-alc4080-s16" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "node.name" = "~alsa_output\\.usb-Generic_USB_Audio.*"; } ];
              actions.update-props = {
                "audio.format" = "S16LE";
              };
            }
          ];
        };
        # xdg-desktop-portal Realtime interface fails here (fstatat ns/pid error),
        # so clients fall back to low-priority scheduling instead of proper RT.
        # rtkit path works fine (confirmed via rtkit-daemon), so go straight to it.
        extraConfig.client."10-disable-rtportal" = {
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
      };

      boot.blacklistedKernelModules = [ "amdgpu" ];

      boot.resumeDevice = "/dev/disk/by-uuid/6b1233d8-aa43-47d7-8c95-3a8c9f14038c";

      # nvidia fbdev console: gives DRM a real modeset on resume/VT-switch.
      # Fixes black session + tty monitors-sleep after hibernate (nv_drm plane-fence/flip-timeout).
      boot.kernelParams = [ "nvidia_drm.fbdev=1" ];

      hardware.graphics.enable = true;
      hardware.nvidia = {
        modesetting.enable = true;
        open = false;
        powerManagement.enable = true; # save VRAM across hibernate
        # 595.x breaks surface re-registration after S4 resume (session crash);
        # see github.com/NVIDIA/open-gpu-kernel-modules/issues/1136
        package = config.boot.kernelPackages.nvidiaPackages.latest;
      };

      nixpkgs.config.allowUnfree = true;
      # xdpw 0.8.x ext_image_copy_capture path gives frozen-first-frame screencast on
      # mango+nvidia; 0.7.1 predates it (zwlr_screencopy only). drop with nixpkgs-xdpw input
      nixpkgs.overlays = [
        (final: prev: {
          xdg-desktop-portal-wlr =
            inputs.nixpkgs-xdpw.legacyPackages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-wlr;
        })
        # mopidy: bump core + extensions to mopidy 4 stable (see modules/overlays/mopidy.nix)
        self.overlays.mopidy
        # obs postFixup runs addDriverRunpath over $out/lib only, so the obs-nvenc-test
        # probe in $out/bin can't dlopen libnvidia-encode and OBS decides NVENC is absent
        # (log: "Test process failed: nvenc_lib"). See NixOS/nixpkgs#382666.
        (final: prev: {
          obs-studio = prev.obs-studio.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              for f in $out/bin/.obs-nvenc-test-wrapped $out/bin/obs-nvenc-test; do
                [ -f "$f" ] && addDriverRunpath "$f"
              done
            '';
          });
        })
      ];
      # pnpm only build-time dep of vesktop; remove once nixpkgs bumps pnpm
      nixpkgs.config.permittedInsecurePackages = [
        "pnpm-10.29.2"
      ];

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment.systemPackages = with pkgs; [
        # System
        vim
        waybar
        quickshell
        ghostty
        btop
        rofi
        papirus-icon-theme # app icons for rofi drun (Adwaita lacks them)
        jq
        wlr-randr
        swayidle
        wayland-pipewire-idle-inhibit
        wlopm
        bluetui # bluetooth TUI, opened from the waybar bluetooth module
        cosmic-files # COSMIC file manager, runs standalone outside the COSMIC session
        mpv
        inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww

        # Dev
        tree
        neovim
        tmux
        wget
        fzf
        ripgrep
        lazygit
        git
        claude-code
        gcc
        clang
        cl
        zig
        go
        gopls
        nodejs # pnpm needs a node runtime; also what vite/svelte-kit run on
        pnpm
        nixd
        nixfmt
        marksman # markdown LSP
        tree-sitter # nvim-treesitter main requires the CLI to build parsers

        # Screenshot / screen recording
        grim
        slurp
        wl-clipboard
        wf-recorder
        ffmpeg # screen-record.sh remuxes mkv -> mp4 (stream copy)

        # Notifications
        mako
        libnotify

        # Misc
        fastfetch
        vesktop
        signal-desktop
        spotify
        pulsemixer
        playerctl
        obs-studio # screen capture via existing pipewire/wlr portal; NVENC via nvidia driver

        # rofi script modi: list running procs by mem, select to kill.
        (writeShellScriptBin "rofi-kill" ''
          if [ -z "$1" ]; then
            ${procps}/bin/ps -eo pid,comm,%mem,%cpu --sort=-%mem --no-headers \
              | ${gawk}/bin/awk '{ printf "%-8s %-25s mem:%s%% cpu:%s%%\n", $1, $2, $3, $4 }'
          else
            pid=$(echo "$1" | ${gawk}/bin/awk '{print $1}')
            ${procps}/bin/kill "$pid" 2>/dev/null || ${procps}/bin/kill -9 "$pid" 2>/dev/null
          fi
        '')

        # rofi confirm prompt for poweroff. In PATH rather than run from the repo so
        # the "nixos-dotfiles" path can't false-match rofi drun's exec field search.
        (writeShellScriptBin "shutdown-confirm" ''
          choice=$(printf 'No\nYes' | ${rofi}/bin/rofi -dmenu -p "Are you sure?")
          [ "$choice" = "Yes" ] && ${systemd}/bin/systemctl poweroff
        '')

        # waybar custom/media: python3 with pygobject + playerctl GIR typelib
        (writeShellScriptBin "waybar-mediaplayer" ''
          export GI_TYPELIB_PATH=${playerctl}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}
          exec ${
            python3.withPackages (ps: [ ps.pygobject3 ])
          }/bin/python3 "$HOME/.config/waybar/mediaplayer.py" "$@"
        '')

      ];

      programs.xwayland.enable = true;
      programs.dconf.enable = true; # required by easyeffects service

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      system.stateVersion = "26.05";
    };
}
