{ self, inputs, ... }:
{
  flake.nixosModules.sddm =
    { pkgs, ... }:
    let
      # astronaut copies Background into the store, so sddm (own user) can read it.
      # /home is mode 700, so the wallpaper must come from the store, not Downloads.
      sddm-astronaut = pkgs.sddm-astronaut.override {
        embeddedTheme = "astronaut";
        themeConfig = {
          Background = "${./wallpaper.png}";
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
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true; # run sddm greeter as wayland session
        package = pkgs.kdePackages.sddm; # qt6 sddm, matches astronaut
        theme = "sddm-astronaut-theme";
        extraPackages = sddm-astronaut.propagatedBuildInputs;
      };

      # theme must sit in sddm's theme search path
      environment.systemPackages = [
        sddm-astronaut
      ];

      services.displayManager.sessionPackages = [
        (session "mango-wl" "config.conf")
        (session "mango-qs" "config-qs.conf")
      ];
    };
}
