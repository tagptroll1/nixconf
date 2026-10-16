# mopidy - managed by the Packages menu
#
# The mopidy 4 bump it needs is an overlay, which is build plumbing rather than
# part of this app: see modules/overlays/mopidy.nix.
{
  apps.mopidy = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      {
        pkgs,
        lib,
        ...
      }:
      let
        extensions = [
          pkgs.mopidy-mpd # MPD frontend on 6600, for mpc CLI control
          pkgs.mopidy-mpris # exposes mopidy to desktop MPRIS controls
          pkgs.mopidy-spotify
        ];

        mopidyEnv = pkgs.buildEnv {
          name = "mopidy-with-extensions-${pkgs.mopidy.version}";
          paths = lib.closePropagation extensions;
          pathsToLink = [ "/${pkgs.mopidyPackages.python.sitePackages}" ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            makeWrapper ${lib.getExe pkgs.mopidy} $out/bin/mopidy \
              --prefix PYTHONPATH : $out/${pkgs.mopidyPackages.python.sitePackages}
          '';
        };

        # Spotify client_id/client_secret live in ~/.config/mopidy/secrets.conf
        # (not the nix store); mopidyStart checks for them.
        mopidyConf = pkgs.writeText "mopidy.conf" ''
          [mpd]
          enabled = true
          hostname = 127.0.0.1
          port = 6600

          [mpris]
          enabled = true

          [spotify]
          enabled = true

          # The defaults use $XDG_MUSIC_DIR, which nothing defines here and
          # mopidy refuses to leave unexpanded, so the file backend fails.
          [file]
          media_dirs = ~/Music|Music

          [m3u]
          base_dir =
        '';

        # Without credentials Spotify fails with an error that does not say
        # where they come from, so say it and disable the extension cleanly.
        mopidyStart = pkgs.writeShellScript "mopidy-start" ''
          secrets=$HOME/.config/mopidy/secrets.conf
          args=()
          if ! { grep -Eq '^\s*client_id\s*=\s*\S' "$secrets" \
            && grep -Eq '^\s*client_secret\s*=\s*\S' "$secrets"; } 2>/dev/null; then
            echo "Spotify disabled: no client_id/client_secret in $secrets." \
              "Authenticate at https://mopidy.com/ext/spotify/#authentication, save the" \
              "[spotify] block it prints to that file (chmod 600), then run:" \
              "systemctl --user restart mopidy" >&2
            args+=(-o spotify/enabled=false)
          fi
          exec ${mopidyEnv}/bin/mopidy --config ${mopidyConf}:"$secrets" "''${args[@]}"
        '';
      in
      {
        home.packages = [ pkgs.mpc ];

        systemd.user.services.mopidy = {
          Unit = {
            Description = "mopidy music server (user session, pipewire audio)";
            After = [ "pipewire.service" ];
          };
          Service = {
            ExecStart = mopidyStart;
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
