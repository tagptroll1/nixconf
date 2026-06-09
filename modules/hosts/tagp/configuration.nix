{ self, inputs, ... }:
let
  host = "nixos";
in
{
  flake.nixosModules.tagpConfiguration =
    { pkgs, lib, ... }:
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

      # Audio
      security.rtkit.enable = true;
      services.pulseaudio.enable = false;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
      };

      boot.blacklistedKernelModules = [ "amdgpu" ];

      boot.resumeDevice = "/dev/disk/by-uuid/6b1233d8-aa43-47d7-8c95-3a8c9f14038c";

      # nvidia fbdev console: gives DRM a real modeset on resume/VT-switch.
      # Fixes black session + tty monitors-sleep after hibernate (nv_drm plane-fence/flip-timeout).
      boot.kernelParams = [ "nvidia_drm.fbdev=1" ];

      # If session stays black after resume but tty works, fbdev wasn't enough:
      # the compositor's GPU channel faults (Xid 13). Next thing to try is restarting
      # the session on resume (loses open windows, so last resort), e.g.:
      #   systemd.services."restart-session-on-resume" = {
      #     wantedBy = [ "post-resume.target" ];
      #     after = [ "post-resume.target" "nvidia-resume.service" ];
      #     script = "systemctl restart display-manager";
      #   };

      hardware.graphics.enable = true;
      hardware.nvidia = {
        modesetting.enable = true;
        open = false;
        powerManagement.enable = true; # save VRAM across hibernate
      };

      nixpkgs.config.allowUnfree = true;

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
        wlopm
        inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww

        # Dev
        tree
        neovim
        wget
        fzf
        ripgrep
        zoxide
        lazygit
        git
        claude-code
        gcc
        clang
        cl
        zig
        nixd
        nixfmt

        # Screenshot
        grim
        slurp
        wl-clipboard

        # Notifications
        mako
        libnotify

        # Misc
        fastfetch
        vesktop
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
