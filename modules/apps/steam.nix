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
          # Steam's LD_LIBRARY_PATH swaps in its runtime's old libSDL2, which the sdl
          # backend can't start on. DT_RPATH outranks LD_LIBRARY_PATH (RUNPATH doesn't),
          # so gamescope keeps its own libs while the game still inherits Steam's env.
          package = pkgs.gamescope.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              bin=$out/bin/.gamescope-wrapped
              ${pkgs.lib.getExe pkgs.patchelfUnstable} --force-rpath \
                --set-rpath "$(${pkgs.lib.getExe pkgs.patchelfUnstable} --print-rpath $bin)" $bin
            '';
          });
          # gamescope never gets mango's keymap and falls back to us
          env = {
            XKB_DEFAULT_LAYOUT = "no";
            XKB_DEFAULT_VARIANT = "nodeadkeys";
          };
          # sdl: only backend that syncs host clipboard into the game.
          # output side matches the main monitor; games add only -w/-h
          args = [
            "--backend sdl"
            "-f"
            "-W 3440"
            "-H 1440"
            "-r 240"
            "-S fit"
            "--force-grab-cursor"
          ];
        };
      };
  };
}
