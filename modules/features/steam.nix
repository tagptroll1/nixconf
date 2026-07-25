{ self, inputs, ... }:
{
  flake.nixosModules.steam =
    { pkgs, ... }:
    {
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };

      programs.gamemode.enable = true;

      # steam shader pre-compile (fossilize_replay) saturates all cores even at nice 19;
      # SCHED_IDLE + idle io = only runs on cycles game doesn't want
      services.ananicy = {
        enable = true;
        package = pkgs.ananicy-cpp;
        # empty provider: skip community ruleset, apply extraRules only
        rulesProvider = pkgs.runCommand "ananicy-no-default-rules" { } ''
          mkdir -p $out/etc/ananicy.d/00-default
        '';
        extraRules = [
          {
            name = "fossilize_replay";
            sched = "idle";
            ioclass = "idle";
          }
        ];
      };

      programs.gamescope = {
        enable = true;
        enableWsi = true;
        capSysNice = false;
      };
    };
}
