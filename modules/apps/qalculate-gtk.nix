# qalculate-gtk - managed by the Packages menu
{
  apps.qalculate-gtk = {
    enable = false; # Packages menu toggles this
    scope = "home";
    module =
      {
        lib,
        pkgs,
        ...
      }:
      {
        home.packages = [ pkgs.qalculate-gtk ];

        # A calculator is a glance, not a tile. The binary carries both spellings
        # of its name (argv0 and the GApplication id), and mango matches app_id as
        # a PCRE, so the rule takes whichever one the toplevel announces.
        mango.windowRules = [ "app_id:(qalculate-gtk|io\\.github\\.Qalculate),is_floating:1" ];

        # Out of the box qalculate opens as a CAS: a function keypad beside the number
        # pad, RPN stack, conversion pane, three-line input and a result view that eats
        # every spare pixel. Strip it to a plain calculator and pin the tweaks made in
        # Preferences, so the window comes back the same after any rebuild:
        #
        #   visible_keypad   bitmask, [Mode]. 2 = HIDE_LEFT_KEYPAD, which drops the
        #                    function stack. Bit 4 (HIDE_RIGHT_KEYPAD) must stay off -
        #                    table_buttons, the digit and operator grid, sits inside
        #                    box_right_buttons (data/main.ui:7004), so 4 blanks the
        #                    keypad entirely. Bit 1 (PROGRAMMING_KEYPAD) stays off too.
        #   expression_lines 1-line input. The preferences spin button floors at 2
        #                    (adjustment_expression_lines); only the cfg reaches 1.
        #   custom_result_height  pixels, not lines. >0 pins the result view; unset it
        #                    auto-sizes to fill the window.
        #
        # qalculate rewrites the whole cfg on exit, so this cannot be a nix symlink -
        # it is enforced here on every activation. Changing any of these keys from the
        # GUI will not survive a rebuild; that is deliberate. Window size and history
        # contents are left alone. visible_keypad lives in [Mode], the rest in
        # [General], hence the section-aware merge.
        home.activation.qalculateBasicLayout = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          cfg="$HOME/.config/qalculate/qalculate-gtk.cfg"
          run mkdir -p "$(dirname "$cfg")"
          [ -e "$cfg" ] || run touch "$cfg"

          run ${pkgs.gawk}/bin/awk -v out="$cfg.hm-new" '
            BEGIN {
              # layout
              want["General|show_keypad"] = 1
              want["General|show_history"] = 1
              want["General|show_stack"] = 0
              want["General|show_convert"] = 0
              want["General|rpn_keys"] = 0
              want["General|persistent_keypad"] = 1
              want["General|minimal_mode"] = 0
              want["Mode|visible_keypad"] = 2
              # compact input and result rows
              want["General|expression_lines"] = 1
              want["General|custom_result_height"] = 1
              want["General|display_expression_status"] = 0
              # behaviour set in Preferences
              want["General|replace_expression"] = 1
              want["General|enable_completion"] = 0
              want["General|close_with_esc"] = 1
              want["General|history_expression_type"] = 0
              want["General|max_history_lines"] = 100
              want["General|calculate_as_you_type_history_delay"] = -1
              want["General|vertical_button_padding"] = 1
              want["General|horizontal_button_padding"] = 1
              want["General|gtk_theme"] = 1
              want["General|division_sign"] = 2
              want["General|automatic_number_fraction_format"] = 1
              want["General|automatic_unit_prefixes"] = 1
              want["Mode|number_fraction_format"] = 1
              want["Mode|approximation"] = 0
              norder = split("General Mode", order, " ")
            }
            function flush_blanks(  i) { for (i = 1; i <= nblank; i++) print "" > out; nblank = 0 }
            function fill_section(sec,  k) {
              for (k in want) if (index(k, sec "|") == 1 && !(k in seen))
                print substr(k, length(sec) + 2) "=" want[k] > out
            }
            function close_section() {
              if (section != "") fill_section(section)
              flush_blanks()
            }
            /^$/ { nblank++; next }
            /^\[.*\]$/ {
              close_section()
              section = substr($0, 2, length($0) - 2)
              found[section] = 1
              print > out; nout++
              next
            }
            {
              flush_blanks()
              split($0, kv, "=")
              k = section "|" kv[1]
              if (k in want) { print kv[1] "=" want[k] > out; seen[k] = 1 }
              else print > out
              nout++
            }
            END {
              close_section()
              for (i = 1; i <= norder; i++) {
                if (order[i] in found) continue
                if (nout) print "" > out
                print "[" order[i] "]" > out
                fill_section(order[i])
                nout++
              }
            }
          ' "$cfg"
          run mv "$cfg.hm-new" "$cfg"
        '';
      };
  };
}
