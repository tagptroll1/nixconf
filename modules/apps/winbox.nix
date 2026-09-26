# winbox - managed by the Packages menu
{
  apps.winbox = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      {
        # WinBox 4 is X11-only (bundles just the xcb Qt plugin) and requires
        # OpenGL, but GLX is broken under xwayland with the nvidia driver
        # (X_GLXCreateNewContext -> BadValue). Force mesa's software GLX so it
        # renders via llvmpipe — plenty for a config GUI.
        home.packages = [
          (pkgs.symlinkJoin {
            name = "winbox-wrapped";
            paths = [ pkgs.winbox ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/WinBox \
                --set __GLX_VENDOR_LIBRARY_NAME mesa \
                --set LIBGL_ALWAYS_SOFTWARE 1
            '';
          })
        ];
      };
  };
}
