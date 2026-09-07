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
        for script in $src/*; do
          name=$(basename "$script")
          install -Dm755 "$script" "$out/bin/$name"
          wrapProgram "$out/bin/$name" --prefix PATH : "$runtimeDeps:$out/bin"
        done
      '';
in
{
  flake.nixosModules.omarchy =
    { pkgs, ... }:
    {
      environment.systemPackages = [ (mkOmarchyBin pkgs) ];
    };

  flake.homeModules.omarchy =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      omarchyPath = "${config.home.homeDirectory}/nixos-dotfiles/config/omarchy";
      omarchyBin = mkOmarchyBin pkgs;
    in
    {
      # shell.qml sits at the root of this one, so quickshell picks it up as its
      # default config: `qs` and `qs ipc call ...` need no -c/-p.
      home.file.".config/quickshell".source = config.lib.file.mkOutOfStoreSymlink "${omarchyPath}/shell";
      # OMARCHY_PATH points here; the shell and every omarchy-* helper resolve
      # plugins, themes, templates and the menu definition relative to it.
      home.file.".config/omarchy".source = config.lib.file.mkOutOfStoreSymlink omarchyPath;
      # config-qs.conf sets this for the quickshell session; set it here too so
      # the helpers also work from a terminal and from the waybar session.
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
