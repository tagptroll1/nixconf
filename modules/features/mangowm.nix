{ self, inputs, ... }:
{
  flake.nixosModules.mangowm =
    { pkgs, ... }:
    {
      imports = [ inputs.mangowm.nixosModules.mango ];

      programs.mango.enable = true;
      programs.mango.addLoginEntry = false; # SDDM uses the Quickshell session launcher.
      # Stage layout lives in a patch so mango updates only touch small hooks;
      # a failed hunk stops the build instead of shipping a broken layout.
      programs.mango.package =
        inputs.mangowm.packages.${pkgs.stdenv.hostPlatform.system}.mango.overrideAttrs
          (old: {
            patches = (old.patches or [ ]) ++ [ ./mango-stage.patch ];
          });
    };
}
