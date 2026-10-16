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
        self.nixosModules.fonts
        self.nixosModules.sddm
        self.nixosModules.omarchy
        self.nixosModules.apps
      ];

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.timeout = 0; # skip menu; hold Space at boot to show it
      boot.kernelPackages = pkgs.linuxPackages_latest;

      networking.hostName = host;
      networking.networkmanager.enable = true;

      # The bar's Tailscale panel runs the CLI as this user, so it has to be
      # operator to toggle without root. "client" loosens rp_filter so exit
      # nodes route.
      services.tailscale = {
        enable = true;
        useRoutingFeatures = "client";
        extraSetFlags = [ "--operator=tagp" ];
      };

      time.timeZone = "Europe/Oslo";

      # Where the network panel's map draws routes from.
      services.networker.origin = {
        latitude = 59.9139;
        longitude = 10.7522;
      };

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
        # Keeps the memory clock floor below while no client holds the GPU.
        nvidiaPersistenced = true;
      };

      # Shell power panel switches profiles through it.
      services.power-profiles-daemon.enable = true;

      # Leaving P8 (405 MHz memory) stalls presentation for ~100 ms, so the first
      # shell animation after idle stutters. An 810 MHz floor avoids it for ~10 W
      # idle; the max stays open for games. Re-applied after resume in case S4
      # resets it.
      systemd.services.nvidia-memclock-floor = {
        description = "NVIDIA memory clock floor";
        wantedBy = [ "multi-user.target" "post-resume.target" ];
        after = [ "nvidia-persistenced.service" "post-resume.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi -lmc 810,10501";
        };
      };

      nixpkgs.config.allowUnfree = true;
      # xdpw 0.8.x ext_image_copy_capture path gives frozen-first-frame screencast on
      # mango+nvidia; 0.7.1 predates it (zwlr_screencopy only). drop with nixpkgs-xdpw input
      nixpkgs.overlays = [
        (final: prev: {
          xdg-desktop-portal-wlr =
            inputs.nixpkgs-xdpw.legacyPackages.${prev.stdenv.hostPlatform.system}.xdg-desktop-portal-wlr;
        })
        # mopidy: bump core + extensions to mopidy 4 stable (see modules/overlays/mopidy.nix).
        # Build plumbing for modules/apps/mopidy.nix - an overlay is not a home option.
        self.overlays.mopidy
        # Build plumbing for modules/apps/obs-studio.nix.
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
        # quickshell only pulls qtbase/qtsvg, whose image plugins are gif/ico/jpeg
        # (+ png/bmp built in). Without qtimageformats, every webp the picker hands
        # Qt directly - the lazy path, before a thumbnail exists - renders blank.
        (final: prev: {
          quickshell = prev.symlinkJoin {
            name = "quickshell-${prev.quickshell.version}";
            paths = [ prev.quickshell ];
            nativeBuildInputs = [ prev.makeWrapper ];
            postBuild = ''
              for bin in $out/bin/*; do
                wrapProgram "$bin" \
                  --prefix QT_PLUGIN_PATH : ${prev.qt6.qtimageformats}/lib/qt-6/plugins
              done
            '';
            inherit (prev.quickshell) meta;
          };
        })
      ];
      # pnpm only build-time dep of vesktop (modules/apps/vesktop.nix); remove once
      # nixpkgs bumps pnpm. nixpkgs.config is system-wide, so it cannot live there.
      nixpkgs.config.permittedInsecurePackages = [
        "pnpm-10.29.2"
      ];

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment.systemPackages = with pkgs; [
        # System
        vim
        quickshell
        ghostty
        papirus-icon-theme # app icons for launchers (Adwaita lacks them)
        yaru-theme # the Yaru-* icon themes omarchy themes name in their icons.theme
        jq
        wlr-randr
        swayidle
        wayland-pipewire-idle-inhibit
        wlopm
        wlsunset # night light for the quickshell shell (wlr-gamma-control)
        libxkbcommon # xkbcli, for the keyboard-layout widget's language codes

        # Dev - the toolchains themselves are apps (modules/apps/*-toolchain.nix);
        # these two stay because a flake build and root both need them.
        git
        wget

        # Screenshot / screen recording
        grim
        slurp
        wl-clipboard
        wf-recorder
        ffmpeg # screen-record.sh remuxes mkv -> mp4 (stream copy)

        # Notifications
        libnotify

        # Misc
        playerctl

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
