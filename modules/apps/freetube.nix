# freetube - managed by the Packages menu
#
# System scope: FreeTube runs as a system unit so it can join the `proton`
# network namespace, whose only way out is a WireGuard tunnel. A dead tunnel
# leaves it offline instead of on the bare connection. Inside that, a nixpak
# (bwrap) sandbox shows it nothing of $HOME but its profile and
# ~/Videos/FreeTube.
#
# The tunnel reads /etc/wireguard/proton-netns.conf, a Proton WireGuard config
# kept out of the repo (root, 0600). Give it its own key: one shared with
# another live tunnel makes the server flip between the two.
{ inputs, ... }:
{
  apps.freetube = {
    enable = true; # Packages menu toggles this
    scope = "system";
    module =
      { pkgs, lib, ... }:
      let
        netns = "proton";
        wgConf = "/etc/wireguard/proton-netns.conf";
        wgConfHowTo =
          "Create a WireGuard config with a new key at account.protonvpn.com -> Downloads, "
          + "then: sudo install -Dm600 <file>.conf ${wgConf}";

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

        # A system unit inherits none of the session, so rebuild what the
        # sandbox needs to reach the compositor, the bus and audio.
        session = pkgs.writeShellScript "freetube-session" ''
          export XDG_RUNTIME_DIR=/run/user/$(id -u)
          export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
          for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
            if [[ -S $socket ]]; then
              export WAYLAND_DISPLAY=''${socket##*/}
              # Electron picks Wayland over X11 by this, not by WAYLAND_DISPLAY.
              export XDG_SESSION_TYPE=wayland
              break
            fi
          done

          # settings.db is an append-only log where the last line for a key
          # wins, and FreeTube compacts it on load, so pinning a key here keeps
          # everything else set in the app.
          settings=$HOME/.config/FreeTube/settings.db
          mkdir -p "''${settings%/*}"
          echo '{"_id":"useSponsorBlock","value":true}' >> "$settings"

          exec ${sandbox.config.script}/bin/freetube
        '';

        # The sandbox never goes on PATH: run directly it would sit in the host
        # namespace. The launcher only asks systemd for the unit.
        launcher = pkgs.symlinkJoin {
          name = "freetube-launcher";
          paths = [
            # Launched from a menu, a failed start would otherwise say nothing.
            (pkgs.writeShellScriptBin "freetube" ''
              if ! systemctl start "freetube@$(id -un).service"; then
                ${pkgs.libnotify}/bin/notify-send -u critical -a FreeTube "FreeTube did not start" \
                  "Its tunnel needs ${wgConf}. See: journalctl -b -u netns-${netns} -u freetube@$(id -un)"
                exit 1
              fi
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
        environment.systemPackages = [ launcher ];

        # The config is kept out of the repo, so flag its absence at rebuild
        # rather than at the first launch.
        system.activationScripts.freetubeWireguard = ''
          if [[ ! -f ${wgConf} ]]; then
            echo "warning: FreeTube will not start: ${wgConf} is missing. ${wgConfHowTo}" >&2
          fi
        '';

        systemd.services."netns-${netns}" = {
          description = "WireGuard-only network namespace ${netns}";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          path = [
            pkgs.iproute2
            pkgs.wireguard-tools
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "netns-${netns}";
          };
          # Created in the host namespace so its UDP socket stays there and
          # reaches the endpoint; only the interface moves in. Inside, it and lo
          # are all there is, so no route around the tunnel exists.
          script = ''
            if [[ ! -f ${wgConf} ]]; then
              echo "${wgConf} is missing. ${wgConfHowTo}" >&2
              exit 1
            fi

            ip netns add ${netns}
            ip -n ${netns} link set lo up
            ip link add wg-${netns} type wireguard
            wg setconf wg-${netns} <(wg-quick strip ${wgConf})
            ip link set wg-${netns} netns ${netns}

            has6=
            for addr in $(sed -n 's/^Address *= *//p' ${wgConf} | tr ',' ' '); do
              ip -n ${netns} addr add "$addr" dev wg-${netns}
              if [[ $addr == *:* ]]; then
                has6=1
              fi
            done
            ip -n ${netns} link set wg-${netns} up
            ip -n ${netns} route add default dev wg-${netns}
            if [[ -n $has6 ]]; then
              ip -n ${netns} -6 route add default dev wg-${netns}
            fi

            for dns in $(sed -n 's/^DNS *= *//p' ${wgConf} | tr ',' ' '); do
              echo "nameserver $dns"
            done > /run/netns-${netns}/resolv.conf
          '';
          # Also runs after a failed start, so a half-built namespace never
          # blocks the next one.
          postStop = ''
            ip netns del ${netns} || true
            ip link del wg-${netns} 2>/dev/null || true
          '';
        };

        systemd.services."freetube@" = {
          description = "FreeTube for %i in the ${netns} namespace";
          bindsTo = [ "netns-${netns}.service" ];
          after = [ "netns-${netns}.service" ];
          environment.NIXOS_OZONE_WL = "1";
          serviceConfig = {
            User = "%i";
            NetworkNamespacePath = "/run/netns/${netns}";
            BindReadOnlyPaths = [ "/run/netns-${netns}/resolv.conf:/etc/resolv.conf" ];
            ExecStart = session;
          };
        };

        # The instance name is the user it runs as, so each user may start
        # only their own.
        security.polkit.extraConfig = ''
          polkit.addRule(function (action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                action.lookup("unit") == "freetube@" + subject.user + ".service" &&
                ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0) {
              return polkit.Result.YES;
            }
          });
        '';
      };
  };
}
