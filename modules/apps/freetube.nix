# freetube - managed by the Packages menu
#
# A nixpak (bwrap) sandbox shows it nothing of $HOME but its profile and
# ~/Videos/FreeTube. Traffic leaves on the bare connection: YouTube bans VPN
# exit IPs. What it contacts shows up in the network panel's snitch view.
{ inputs, ... }:
{
  apps.freetube = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, lib, ... }:
      let
        # Loads the palette omarchy-theme-set-freetube writes.
        freetube = pkgs.freetube.overrideAttrs (old: {
          patches = old.patches ++ [ ../../patches/freetube-omarchy-theme.patch ];
        });

        mkNixPak = inputs.nixpak.lib.nixpak { inherit lib pkgs; };
        sandbox = mkNixPak {
          config =
            { sloth, ... }:
            {
              imports = with inputs.nixpak.nixpakModules; [
                gui-base
                network
              ];
              app.package = freetube;
              flatpak.appId = "io.freetubeapp.FreeTube";
              # gui-base bundles mesa, which has no NVIDIA userspace.
              gpu.provider = lib.mkForce "nixos";
              timeZone.enable = true;
              dbus.policies = {
                "org.freedesktop.Notifications" = "talk";
                # Chromium registers its player under its own name, not the app ID.
                "org.mpris.MediaPlayer2.chromium.*" = "own";
              };
              bubblewrap = {
                bind.rw = [
                  (sloth.mkdir (sloth.concat' sloth.xdgConfigHome "/FreeTube"))
                  (sloth.mkdir (sloth.concat' sloth.homeDir "/Videos/FreeTube"))
                ];
                bind.dev = [
                  "/dev/nvidia0"
                  "/dev/nvidiactl"
                  "/dev/nvidia-modeset"
                  "/dev/nvidia-uvm"
                ];
                tmpfs = [ "/tmp" ];
                # Links open through the OpenURI portal; a plain xdg-open would
                # look for a browser inside the sandbox.
                env.PATH = "${pkgs.flatpak-xdg-utils}/bin";
                # Without it libpulse re-chmods the read-only bound pulse dir,
                # fails, and Chromium falls back to ALSA, which has no card here.
                env.PULSE_SERVER = sloth.concat [
                  "unix:"
                  sloth.runtimeDir
                  "/pulse/native"
                ];
                newSession = true;
                dieWithParent = true;
              };
            };
        };

        launcher = pkgs.symlinkJoin {
          name = "freetube-launcher";
          paths = [
            (pkgs.writeShellScriptBin "freetube" ''
              # settings.db is an append-only log where the last line for a key
              # wins, and FreeTube compacts it on load, so pinning a key here keeps
              # everything else set in the app.
              settings=$HOME/.config/FreeTube/settings.db
              mkdir -p "''${settings%/*}"
              echo '{"_id":"useSponsorBlock","value":true}' >> "$settings"

              exec ${sandbox.config.script}/bin/freetube
            '')
            (pkgs.makeDesktopItem {
              name = "freetube";
              desktopName = "FreeTube";
              comment = freetube.meta.description;
              exec = "freetube";
              icon = "freetube";
              startupWMClass = "FreeTube";
              categories = [ "Network" ];
            })
          ];
          postBuild = ''
            ln -s ${freetube}/share/icons $out/share/icons
          '';
        };
      in
      {
        home.packages = [ launcher ];
      };
  };
}
