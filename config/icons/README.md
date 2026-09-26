# Shared Icons

[Lucide](https://lucide.dev) SVGs live in `lucide/icons/`, with upstream license
and pinned archive details in `lucide/LICENSE` and `lucide/VENDOR`.
Assets are shared across this config, not tied to one shell or notification server.
Nix installs them at `/run/current-system/sw/share/config-icons/lucide/icons/`.

```sh
send-notification -i bell "Reminder" "Check backup"
send-notification --list-icons
```

Fish completes names after `-i` and `--icon`; file completion remains available.
Matching Lucide names resolve to absolute SVG paths. Other icon arguments keep
their existing behavior (themed names, image paths, emoji, Nerd Font glyphs).
Default info/warning/error icons use `info`, `triangle-alert`, and `circle-x`.

SVGs use `currentColor`. QML consumers should tint their monochrome image with
the current foreground color, as the notification card does. Do not tint photos
or arbitrary app icons. Other consumers can load the shared SVGs directly.

Apply package and completion changes from the repo root:

```sh
sudo nixos-rebuild switch --flake path:.#tagp
```

Open a new Fish shell after applying so completion discovery uses the new package.
