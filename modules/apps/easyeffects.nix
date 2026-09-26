# easyeffects - managed by the Packages menu
{
  apps.easyeffects = {
    enable = true; # Packages menu toggles this
    scope = "home";
    module =
      { pkgs, lib, ... }:
      let
        configPath = ../../config;
      in
      {
        services.easyeffects = {
          enable = true;
          preset = "headset-eq";
          extraPresets = {
            headset-eq = builtins.fromJSON (builtins.readFile (configPath + /easyeffects/headset-eq.json));
            mic-noise-reduction = builtins.fromJSON (
              builtins.readFile (configPath + /easyeffects/mic-noise-reduction.json)
            );
          };
        };

        # EasyEffects only applies the EQ to streams it intercepts, and by default it
        # intercepts a subset and pins itself to one output device. Both keys below make
        # "every output is equalized" a rule instead of a coincidence:
        #
        #   processAllOutputs     every output stream is pulled into easyeffects_sink,
        #                         whatever device it asked for
        #   useDefaultOutputDevice easyeffects_sink follows the default sink, so switching
        #                         output from the bar moves the EQ'd audio with it instead
        #                         of leaving it on the old device
        #
        # EasyEffects owns db/easyeffectsrc at runtime and rewrites it on exit, so this
        # cannot be a nix symlink - it is enforced here on every activation and the daemon
        # is restarted to pick it up. Flipping either toggle in the GUI will not survive a
        # rebuild; that is deliberate.
        home.activation.easyeffectsAlwaysEqualize = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          rc="$HOME/.config/easyeffects/db/easyeffectsrc"
          run mkdir -p "$(dirname "$rc")"
          [ -e "$rc" ] || run touch "$rc"

          run ${pkgs.gawk}/bin/awk -v out="$rc.hm-new" '
            BEGIN { want["processAllOutputs"] = "true"; want["useDefaultOutputDevice"] = "true" }
            function flush_blanks(  i) { for (i = 1; i <= nblank; i++) print "" > out; nblank = 0 }
            function close_section(  k) {
              if (section == "StreamOutputs")
                for (k in want) if (!(k in seen)) print k "=" want[k] > out
              flush_blanks()
            }
            /^$/ { nblank++; next }
            /^\[.*\]$/ {
              close_section()
              section = substr($0, 2, length($0) - 2)
              if (section == "StreamOutputs") found = 1
              print > out; nout++
              next
            }
            {
              flush_blanks()
              split($0, kv, "=")
              if (section == "StreamOutputs" && kv[1] in want) { print kv[1] "=" want[kv[1]] > out; seen[kv[1]] = 1 }
              else print > out
              nout++
            }
            END {
              close_section()
              if (!found) {
                if (nout) print "" > out
                print "[StreamOutputs]" > out
                for (k in want) print k "=" want[k] > out
              }
            }
          ' "$rc"
          run mv "$rc.hm-new" "$rc"

          # Only meaningful inside a live session; a rebuild from a TTY has nothing to poke.
          if ${pkgs.systemd}/bin/systemctl --user -q is-active easyeffects.service 2>/dev/null; then
            run ${pkgs.systemd}/bin/systemctl --user restart easyeffects.service
          fi
        '';
      };
  };
}
