# Everything the vendored omarchy quickshell desktop needs, on both sides:
# the NixOS module packages its helper CLIs, the home module wires the
# checkout in config/omarchy into ~/.config. See config/omarchy/README.md.
{ ... }:
let
  # Upstream leaves its whole bin/ on PATH through $OMARCHY_PATH/bin. Only the
  # helpers the shell and the menu actually call are vendored
  # (config/omarchy/bin); packaging them here pins their runtime deps instead of
  # inheriting whatever the session PATH happens to hold.
  #
  # One derivation for the lot: the scripts call each other, so $out/bin has to
  # be on their own PATH as well.
  mkOmarchyBin =
    pkgs:
    pkgs.runCommand "omarchy-bin"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        src = ../../config/omarchy/bin;
        runtimeDeps = pkgs.lib.makeBinPath (
          with pkgs;
          [
            bash
            coreutils
            findutils
            gawk
            gnugrep
            gnused
            file
            jq
            vips # vipsthumbnail, for the image picker's thumbnails
            util-linux # flock
            procps # pgrep/pkill
            pulseaudio # pactl, a client for the running pipewire-pulse socket
            psmisc # killall
            libnotify # notify-send
            quickshell # qs, for the omarchy-shell IPC wrapper
            tmux
            neovim # nvim --server, for omarchy-theme-set-nvim
            iproute2
            iputils
            networkmanager
            iw
          ]
        );
      }
      ''
        mkdir -p $out/bin
        mkdir -p $out/share/config-icons $out/share/fish/vendor_completions.d
        ln -s ${../../config/icons/lucide} $out/share/config-icons/lucide
        install -m644 ${../../config/fish/completions/send-notification.fish} \
          $out/share/fish/vendor_completions.d/send-notification.fish
        for script in $src/*; do
          name=$(basename "$script")
          install -Dm755 "$script" "$out/bin/$name"
          if [ "$name" = send-notification ]; then
            wrapProgram "$out/bin/$name" --prefix PATH : "$runtimeDeps:$out/bin" \
              --set CONFIG_ICON_DIR "$out/share/config-icons/lucide/icons"
          else
            wrapProgram "$out/bin/$name" --prefix PATH : "$runtimeDeps:$out/bin"
          fi
        done
      '';
in
{
  flake.nixosModules.omarchy =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      # The flake output this host is built from. nixos-rebuild defaults it to
      # networking.hostName, which is not the attr name here, so anything that
      # runs a rebuild has to be told: set beside `nixosConfigurations.<name>`.
      options.omarchy.flakeAttr = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = "nixosConfigurations attribute this host is built from.";
      };

      config.environment.systemPackages = [
        (mkOmarchyBin pkgs)
        pkgs.wtype
      ];

      config.security.pam.services.omarchy-lock-password.allowNullPassword = false;
    };

  flake.homeModules.omarchy =
    {
      config,
      osConfig,
      pkgs,
      lib,
      ...
    }:
    let
      repoPath = "${config.home.homeDirectory}/nixos-dotfiles";
      omarchyPath = "${repoPath}/config/omarchy";
      omarchyBin = mkOmarchyBin pkgs;
    in
    {
      # shell.qml sits at the root of this one, so quickshell picks it up as its
      # default config: `qs` and `qs ipc call ...` need no -c/-p.
      home.file.".config/quickshell".source = config.lib.file.mkOutOfStoreSymlink "${omarchyPath}/shell";
      # OMARCHY_PATH points here; the shell and every omarchy-* helper resolve
      # plugins, themes, templates and the menu definition relative to it.
      home.file.".config/omarchy".source = config.lib.file.mkOutOfStoreSymlink omarchyPath;
      # Where this desktop was built from, written by the build itself. The
      # shell's Packages menu edits modules/apps under `repo` and rebuilds
      # `flake#attr`, so it reads them from here rather than assuming a checkout
      # path or a host name. Not inside .config/omarchy - that is the repo.
      home.file.".config/omarchy-nix.json".text = builtins.toJSON {
        repo = repoPath;
        flake = "path:${repoPath}";
        attr = osConfig.omarchy.flakeAttr;
      };
      # config-qs.conf sets this for the quickshell session; set it here too so
      # the helpers also work from a terminal.
      home.sessionVariables.OMARCHY_PATH = "${config.home.homeDirectory}/.config/omarchy";

      # ~/.local/state/omarchy/current/{theme,background} is mutable state that
      # omarchy-theme-set owns: it stages the picked theme, renders
      # default/themed/*.tpl into it, and repoints the background link. So it
      # cannot be a nix symlink. Seed it once, and never touch a theme the user
      # has since picked. After linkGeneration, so the older generation's symlink
      # at that path is gone before the check runs.
      home.activation.omarchySeedTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -e "$HOME/.local/state/omarchy/current/theme" ]; then
          run mkdir -p "$HOME/.local/state/omarchy/current"
          run env OMARCHY_PATH="$HOME/.config/omarchy" OMARCHY_THEME_HEADLESS=1 \
            ${omarchyBin}/bin/omarchy-theme-set tokyo-night
        fi
      '';

      home.activation.sddmBackground = lib.hm.dag.entryAfter [ "omarchySeedTheme" ] ''
        run ${omarchyBin}/bin/sddm-background-sync
      '';

      # omarchy-theme-set-claude runs on every theme change and refreshes
      # ~/.claude/themes/omarchy.json, which Claude Code hot-reloads. But it only
      # points settings.json at that theme when passed --activate, which nothing
      # does. Do it once here, keeping the theme it replaces alongside so the
      # original is recoverable, and never override a theme picked later.
      home.activation.omarchyActivateClaudeTheme = lib.hm.dag.entryAfter [ "omarchySeedTheme" ] ''
        settings="$HOME/.claude/settings.json"
        current=""
        if [ -f "$settings" ]; then
          current=$(${pkgs.jq}/bin/jq -r '.theme // empty' "$settings" 2>/dev/null || true)
        fi

        if [ "$current" != "custom:omarchy" ]; then
          if [ -n "$current" ]; then
            run cp "$settings" "$settings.omarchy-previous"
          fi
          # Non-fatal: it refuses when no theme is staged, which must not fail a rebuild.
          run env OMARCHY_PATH="$HOME/.config/omarchy" \
            ${omarchyBin}/bin/omarchy-theme-set-claude --activate || true
        fi
      '';
    };
}
