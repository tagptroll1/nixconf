# steam - managed by the Packages menu
#
# System scope: steam, gamescope and gamemode are NixOS options (wrappers, a
# firewall hole, a setcap'd binary), none of which home-manager can set.
{
  apps.steam = {
    enable = true; # Packages menu toggles this
    scope = "system";
    module =
      { pkgs, ... }:
      {
        programs.steam = {
          enable = true;
          package = pkgs.steam.override { extraArgs = "-pipewire"; };
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
  };
}
