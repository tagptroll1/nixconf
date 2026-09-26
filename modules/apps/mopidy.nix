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

        # Spotify client_id/client_secret/auth live in secrets.conf (not the nix store).
        mopidyConf = pkgs.writeText "mopidy.conf" ''
          [mpd]
          enabled = true
          hostname = 127.0.0.1
          port = 6600

          [mpris]
          enabled = true

          [spotify]
          enabled = true
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
            ExecStart = "${mopidyEnv}/bin/mopidy --config ${mopidyConf}:%h/.config/mopidy/secrets.conf";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  };
}
