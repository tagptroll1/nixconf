// The menu, declared. Every static row on this desktop is here; the only rows
// built elsewhere are the ones that cannot be known in advance — installed
// applications, the repo's app modules, and nixpkgs search results.
//
// A node is `{ id, icon, label, children }` plus whichever of these apply:
//   title        header text while the submenu is open; defaults to label
//   description  second line, shown while searching
//   aliases      extra `shell toggle omarchy.menu '{"menu":"<name>"}'` routes;
//                also searchable
//   action       what picking the row does (see below)
//   provider     rows come from a provider instead of `children`
//   target       redirect to another id rather than opening children
//   detached     reachable by id, but not listed under its parent
//
// An action is a shell command, or one of the verbs the menu answers itself:
//   summon:<id>              open a shell panel (the emoji picker, the clipboard)
//   service:<id>:<method>    call a running service (nightlight, notifications)
//   nix:<verb>[:<arg>...]    the Packages section's own writes and rebuilds
//
// Ids are addresses: keybinds name them (config/mango/config-qs.conf opens
// `style.theme`), so renaming one is a breaking change.

var EDITOR_APPID = "floating.nixedit"

// Config files this desktop actually has. Upstream's rows pointed at Hyprland's
// lua config; these point at the mango config in the repo, which is what a
// change here has to end up in to survive a rebuild.
function editConfig(path) {
  return "ghostty --class=" + EDITOR_APPID + " -e nvim " + path
}

// Store maintenance runs in a terminal: sudo asks for the password there, and
// what nix prints at the end - paths freed, bytes reclaimed - is the point of
// running it. The window stays up afterwards so that count can be read.
function storeTerminal(command) {
  return "ghostty --class=floating.nixbuild -e bash -lc '" + command
    + '\nprintf "\\n[enter to close] "\nread -r _' + "'"
}

// Generations are what pin paths in the store, so the user's own profiles are
// collected first and the root sweep then has something to free.
function garbageCollect(spec) {
  return storeTerminal("nix-collect-garbage " + spec + "; sudo nix-collect-garbage " + spec)
}

function tree() {
  return [
    {
      id: "apps",
      icon: "󰀻",
      label: "Apps",
      aliases: ["app", "applications"],
      provider: "apps"
    },
    {
      id: "packages",
      icon: "󰏖",
      label: "Packages",
      title: "Packages",
      aliases: ["nix", "pkg", "software"],
      children: [
        {
          id: "packages.install",
          icon: "󰐕",
          label: "Install",
          description: "Search nixpkgs and home-manager",
          provider: "nix-search"
        },
        {
          id: "packages.remove",
          icon: "󰍴",
          label: "Remove",
          description: "Disable an app, keeping its module",
          provider: "nix-apps-enabled"
        },
        {
          id: "packages.update",
          icon: "󰚰",
          label: "Update",
          description: "Update the flake inputs and rebuild",
          aliases: ["update", "upgrade"],
          children: [
            {
              id: "packages.update.all",
              icon: "󰚰",
              label: "Everything",
              description: "Update every flake input and rebuild",
              action: "nix:update"
            },
            {
              id: "packages.update.nixpkgs",
              icon: "󱄅",
              label: "Packages (nixpkgs)",
              description: "Newer versions of every nixpkgs package; other inputs stay pinned",
              action: "nix:update:nixpkgs"
            },
            {
              // A flake pins packages per input, so one input is the
              // smallest thing that can be updated on its own.
              id: "packages.update.input",
              icon: "󰜷",
              label: "One input",
              description: "Pick a single flake input (mango, home-manager, ...)",
              provider: "nix-inputs"
            }
          ]
        },
        {
          id: "packages.rebuild",
          icon: "󱁤",
          label: "Rebuild",
          description: "Rebuild the system from the config as it stands",
          action: "nix:rebuild"
        },
        {
          id: "packages.configure",
          icon: "󰒓",
          label: "Configure",
          description: "Edit an app module in neovim",
          provider: "nix-apps-all"
        },
        {
          id: "packages.cleanup",
          icon: "󰃢",
          label: "Cleanup",
          description: "Reclaim disk space in the nix store",
          aliases: ["gc", "garbage", "optimise"],
          children: [
            {
              id: "packages.cleanup.optimize",
              icon: "󰌷",
              label: "Optimize",
              description: "Hard-link identical files in the store",
              action: storeTerminal("sudo nix store optimise")
            },
            {
              id: "packages.cleanup.collect",
              icon: "󰩹",
              label: "Clean up",
              description: "Delete old generations and the paths they held",
              children: [
                {
                  id: "packages.cleanup.collect.7d",
                  icon: "󰅐",
                  label: "Keep last 7 days",
                  description: "Delete generations older than 7 days",
                  action: garbageCollect("--delete-older-than 7d")
                },
                {
                  id: "packages.cleanup.collect.14d",
                  icon: "󰅐",
                  label: "Keep last 14 days",
                  description: "Delete generations older than 14 days",
                  action: garbageCollect("--delete-older-than 14d")
                },
                {
                  id: "packages.cleanup.collect.30d",
                  icon: "󰅐",
                  label: "Keep last 30 days",
                  description: "Delete generations older than 30 days",
                  action: garbageCollect("--delete-older-than 30d")
                },
                {
                  id: "packages.cleanup.collect.all",
                  icon: "󰗨",
                  label: "Everything old",
                  description: "Delete every generation but the current one",
                  action: garbageCollect("-d")
                }
              ]
            }
          ]
        },
        {
          // Where a finished change hands over to the rebuild: switched to
          // rather than picked, so it is not listed beside the rows above.
          id: "packages.confirm",
          icon: "󱁤",
          label: "Rebuild",
          detached: true
        }
      ]
    },
    {
      id: "style",
      icon: "",
      label: "Style",
      children: [
        {
          id: "style.theme",
          icon: "󰸌",
          label: "Theme",
          aliases: ["theme", "themes"],
          action: "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\""
        },
        {
          id: "style.background",
          icon: "",
          label: "Background",
          aliases: ["background", "wallpaper"],
          action: "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""
        }
      ]
    },
    {
      id: "trigger",
      icon: "󱓞",
      label: "Trigger",
      children: [
        {
          id: "trigger.clipboard",
          icon: "󰅌",
          label: "Clipboard",
          description: "Clipboard history",
          aliases: ["clipboard", "clip", "history"],
          action: "summon:omarchy.clipboard"
        },
        {
          id: "trigger.emoji",
          icon: "",
          label: "Emoji",
          aliases: ["emoji", "emojis"],
          action: "summon:omarchy.emojis"
        },
        {
          id: "trigger.toggle.nightlight",
          icon: "󰔎",
          label: "Nightlight",
          action: "service:omarchy.nightlight:toggle"
        },
        {
          id: "trigger.toggle.notifications",
          icon: "󰂛",
          label: "Notifications",
          description: "Silence notifications",
          action: "service:omarchy.notifications:toggleDoNotDisturb"
        },
        {
          id: "trigger.reload.shell",
          icon: "󰑓",
          label: "Reload Quickshell",
          description: "Kill the shell and start it again",
          aliases: ["restart-shell", "reload-shell"],
          // setsid so the relaunch outlives the shell that asked for it: the
          // script's whole job happens after this process is gone.
          action: 'setsid -f bash "$HOME/nixos-dotfiles/config/omarchy/bin/restart-shell"'
        },
        {
          id: "trigger.reload.mango",
          icon: "󰑐",
          label: "Reload mango",
          description: "Re-read the compositor config (SUPER+R)",
          aliases: ["reload-config"],
          // A reload that quietly did nothing looks exactly like one that
          // worked, so both outcomes say which one it was.
          action: 'if mmsg dispatch reload_config >/dev/null 2>&1; then'
            + ' send-notification -i refresh-cw "mango reloaded" "Config re-read";'
            + ' else send-notification --type error "mango reload failed"; fi'
        }
      ]
    },
    {
      id: "calculator",
      icon: "󰃬",
      label: "Calculator",
      title: "Calculator",
      description: "Arithmetic, a keypad and what came before (SUPER+SHIFT+C)",
      aliases: ["calc", "arithmetic", "maths"],
      action: "summon:omarchy.calculator"
    },
    {
      id: "keybindings",
      icon: "\udb80\udf0c",
      label: "Keybindings",
      title: "Keybindings",
      description: "Every bind mango has loaded",
      aliases: ["keys", "keybinds", "shortcuts", "hotkeys"],
      action: "summon:omarchy.keybindings"
    },
    {
      id: "setup",
      icon: "",
      label: "Setup",
      aliases: ["settings"],
      children: [
        {
          id: "setup.monitors",
          icon: "󰍹",
          label: "Monitors",
          description: "config/mango/monitors.conf",
          action: editConfig("$HOME/nixos-dotfiles/config/mango/monitors.conf")
        },
        {
          id: "setup.keybindings",
          icon: "",
          label: "Keybindings",
          description: "config/mango/keybinds.conf",
          action: editConfig("$HOME/nixos-dotfiles/config/mango/keybinds.conf")
        }
      ]
    },
    {
      id: "system",
      icon: "",
      label: "System",
      aliases: ["power-menu"],
      children: [
        {
          id: "system.suspend",
          icon: "󰒲",
          label: "Suspend",
          action: 'bash "$HOME/nixos-dotfiles/config/omarchy/bin/system-action" suspend'
        },
        {
          id: "system.hibernate",
          icon: "󰤁",
          label: "Hibernate",
          action: 'bash "$HOME/nixos-dotfiles/config/omarchy/bin/system-action" hibernate'
        },
        {
          id: "system.logout",
          icon: "󰍃",
          label: "Logout",
          description: "Quit mango, back to the greeter",
          action: 'bash "$HOME/nixos-dotfiles/config/omarchy/bin/system-action" logout'
        },
        {
          id: "system.reboot",
          icon: "󰜉",
          label: "Reboot",
          action: 'bash "$HOME/nixos-dotfiles/config/omarchy/bin/system-action" reboot'
        },
        {
          id: "system.shutdown",
          icon: "󰐥",
          label: "Shutdown",
          action: 'bash "$HOME/nixos-dotfiles/config/omarchy/bin/system-action" shutdown'
        }
      ]
    }
  ]
}

// Flatten the tree into the rows the menu navigates. Nesting sets the parent, so
// an id is only ever an address — renaming a parent cannot silently reparent its
// children the way a dotted-id convention would.
function items() {
  var out = []
  append(out, tree(), "root")
  out.push(normalize({ id: "root", label: "Go" }, ""))
  for (var i = 0; i < out.length; i++) out[i].order = i
  return out
}

function append(out, nodes, parent) {
  var list = nodes || []
  for (var i = 0; i < list.length; i++) {
    var node = list[i]
    if (!node || !node.id) continue
    out.push(normalize(node, node.detached ? "" : parent))
    if (node.children) append(out, node.children, node.id)
  }
}

function normalize(node, parent) {
  return {
    id: node.id,
    parent: parent,
    kind: node.action ? "action" : (node.target ? "link" : "menu"),
    icon: node.icon || "",
    iconFont: node.iconFont || "",
    label: node.label || node.id,
    title: node.title || "",
    target: node.target || "",
    description: node.description || "",
    action: node.action || "",
    provider: node.provider || "",
    aliases: node.aliases || [],
    order: 0
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    tree: tree,
    items: items
  }
}
