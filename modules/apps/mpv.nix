# mpv - managed by the Packages menu
{
  apps.mpv = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        home.packages = [ pkgs.mpv ];

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
      };
  };
}
