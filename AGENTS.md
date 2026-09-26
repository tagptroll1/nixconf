# OpenCode Project Instructions

## Hard Rules

- Never modify live system or files under `~/.config`. Edit declarative files in this repo,
  explain why, provide exact apply command, then stop.
- Git is read-only. Never use checkout, restore, reset, add, commit, or remove through git.
- Comments explain why, not mechanics or previous versions, and stay concise.
- Goal is replacing Omarchy custom code with user's own sleek code. Never recommend
  `omarchy-*` wrappers; use direct `notify-send`, `busctl`, or QML primitives.
- Upstream trees vendored here live under `/mnt/bigboi/dev`; inspect real source there.

## Imported Memory

Memory snapshot date: 2026-09-06. Before work involving a topic below, read its detailed
file from `@claude-knowledge/projects/nixos-dotfiles/memory/`. Load only relevant files.

- `nvidia-wlroots-screenshare-fix.md` - screenshare works with amdgpu blacklist; no extra
  environment variables needed.
- `comment-style.md` - concise why-comments only.
- `no-direct-system-edits.md` - declarative repo edits only, never live system changes.
- `no-destructive-git.md` - manually edit reversions; no destructive git commands.
- `waybar-music-mpris.md` - music module uses MPRIS custom/media; Waybar config is live
  out-of-store symlink and needs reload, not rebuild.
- `system-specs.md` - NixOS/mango stack, RTX 4070 Ti, dual monitors and repo layout.
- `mango-per-monitor-layout.md` - scope layout and mfact through `tagrule monitor_serial`;
  explicitly set layouts because reload preserves unmatched-tag state.
- `ghostty-class-gtk-appid.md` - Ghostty class must be dotted GTK app ID for mango match.
- `mango-named-scratchpad.md` - named scratchpad window rule and toggle behavior.
- `mango-idle-inhibit.md` - PipeWire idle inhibitor replacement, Steam rule gap and
  Vesktop blacklist needed for hibernate.
- `hibernate-instant-wake.md` - S4/resume is stable; prior no-input event was pre-kernel
  POST hang.
- `vesktop-screenshare-electron.md` - frozen first frame came from xdg-desktop-portal-
  wlr 0.8.x on mango/NVIDIA; overlay pins 0.7.1.
- `alc4080-onboard-audio.md` - onboard analog is USB ALC4080 with separate front/rear
  sinks; HDA no-codecs log is expected.
- `audio-crackle-investigation.md` - front-panel crackle remains unresolved; consult
  evidence and staged S16LE test before changing anything.
- `ps4-controller-bluetooth.md` - DS4 needs hidp, unplugged pairing and ePSXe SDL override;
  remaining stalls point to MT7922 ACL loss.
- `vendored-source-location.md` - upstream checkouts live under `/mnt/bigboi/dev`.
- `mango-spawn-wordexp.md` - mango spawn uses `wordexp()`; quote shell metacharacters and
  test with `mmsg dispatch`.
- `omarchy-shell-uwsm-assumptions.md` - Omarchy shell assumes Hyprland/UWSM; missing
  launch helpers silently no-op on this setup.
- `omarchy-menu-ipc.md` - menu IPC requires both menu name and JSON argument.
- `apply-changes-where-they-take-effect.md` - live shell config can override repo default
  wholesale; edit source that actually renders.
- `quickshell-dev-loop.md` - no hot reload, duplicate IPC targets can segfault, second
  instance cannot reach tray.
- `migrate-off-omarchy-bloat.md` - replace Omarchy wrappers with direct primitives.

If index and detailed file disagree, detailed file wins. Verify time-sensitive state in
current repo or system before relying on snapshot.

## Display Blackout Follow-Up (2026-09-18)

- User returned after being away, found black screens, and could not wake them with
  mouse/keyboard or DisplayPort reseating. Likely 15-minute idle display-off followed
  by failed wake, not proven root cause. No suspend/hibernate entry in incident boot
  `677dbcf41ac84a2da65fcb9ff44e9d5b`; no incident NVIDIA Xid or kernel panic logged.
- Local CEST timeline: 20:35:47 EasyEffects reports "There are no outputs - creating
  placeholder screen" (Qt Wayland display outputs, not audio); 20:36:42 USB keyboard
  registered; 20:39:40 short power-button press starts clean shutdown. OS stayed alive.
  Next boot starts 20:40:14. Prior Mango session log was replaced on login.
- Diagnostics added: `modules/features/sddm.nix` launches Mango through
  `systemd-cat -t mango-session`; `config/mango/execonce.conf` enables `swayidle -d`.
  Idle timers unchanged: displays off at 900 seconds, hibernate at 1800 seconds.
  Both session launchers built successfully; diff checks passed.
- User confirmed rebuild completed. Fresh login after rebuild not yet confirmed;
  journal routing requires a new session. Verify active logging rather than assuming.
- User chose to wait for recurrence and ping agent, not run controlled blackout test.
  On recurrence inspect `journalctl --since "30 minutes ago" -t mango-session`, plus
  kernel/system journal and boot history. Preserve any current SDDM session log before
  another login if journal routing is not active. Do not trigger display-off tests
  without renewed request. Cause remains unresolved between idle wake handling,
  Mango/wlroots, NVIDIA and display connection behavior.
