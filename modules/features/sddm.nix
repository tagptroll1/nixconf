{ self, inputs, ... }:
{
  flake.nixosModules.sddm =
    { pkgs, ... }:
    let
      # SDDM cannot traverse the private home containing the selected wallpaper.
      sddm-astronaut = pkgs.sddm-astronaut.override {
        embeddedTheme = "astronaut";
        themeConfig = {
          Background = "/var/lib/sddm-wallpaper/background";
          CropBackground = "true";
          FullBlur = "false";
          PartialBlur = "false";
        };
      };
      session =
        name: confFile:
        let
          # sddm's wayland-session ends in `exec $@` (unquoted): word-splits, no
          # shell quoting or $HOME expansion. So Exec must be a single token.
          # Point it at a script that does the expansion itself.
          launcher = pkgs.writeShellScript "${name}-launch" ''
            # Preserve compositor and child-process diagnostics across logins and reboots.
            exec ${pkgs.systemd}/bin/systemd-cat -t mango-session mango -c "$HOME/.config/mango/${confFile}"
          '';
        in
        (pkgs.writeTextDir "share/wayland-sessions/${name}.desktop" ''
          [Desktop Entry]
          Name=${name}
          DesktopNames=mango;wlroots
          Exec=${launcher}
          Type=Application
        '').overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              # Join in new providedSessions attr
              providedSessions = [ name ];
            };
          });
    in
    {
      systemd.tmpfiles.rules = [
        "d /var/lib/sddm-wallpaper 0755 tagp users -"
        "C /var/lib/sddm-wallpaper/background 0644 tagp users - ${./wallpaper.png}"
      ];

      systemd.services.home-manager-tagp.after = [ "systemd-tmpfiles-setup.service" ];

      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true; # run sddm greeter as wayland session
        package = pkgs.kdePackages.sddm; # qt6 sddm, matches astronaut
        theme = "sddm-astronaut-theme";
        # The published background keeps its source format and themes ship webp,
        # which qtbase cannot decode (gif/ico/jpeg only) - without qtimageformats
        # the greeter draws BackgroundColor instead of the wallpaper.
        extraPackages = sddm-astronaut.propagatedBuildInputs ++ [ pkgs.kdePackages.qtimageformats ];
      };

      # theme must sit in sddm's theme search path
      environment.systemPackages = [
        sddm-astronaut
      ];

      services.displayManager.sessionPackages = [
        (session "mango-qs" "config-qs.conf")
      ];
    };
}
