# wowup-cf - managed by the Packages menu
#
# World of Warcraft addon manager.
{ inputs, ... }:
{
  apps.wowup-cf = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, ... }:
      let
        # Pinned ahead of nixpkgs; once it catches up, use pkgs.wowup-cf and drop the
        # wowup-cf-appimage input. Bumping means editing this and the input's URL.
        pname = "wowup-cf";
        version = "2.25.4";
        src = inputs.wowup-cf-appimage;
        appimageContents = pkgs.appimageTools.extract { inherit pname version src; };
      in
      {
        home.packages = [
          (pkgs.appimageTools.wrapType2 {
            inherit pname version src;
            extraInstallCommands = ''
              install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
              substituteInPlace $out/share/applications/${pname}.desktop \
                --replace-fail 'Exec=AppRun' 'Exec=${pname}'
              cp -r ${appimageContents}/usr/share/icons $out/share
            '';
            meta.mainProgram = pname;
          })
        ];
      };
  };
}
