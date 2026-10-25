// Packages section: declarative app management for this NixOS repo.
//
// One file per app under modules/apps/, each registering `apps.<name>` with an
// enable flag, a scope and the module it contributes. Install writes that file,
// Remove flips its flag to false (the template survives, the build shrinks),
// Configure opens it in an editor, Update refreshes the flake and rebuilds.
//
// Rows and commands are built here; Menu.qml owns the processes and the UI.

// The two ways out of a change that has already been written to disk.
function confirmRows(menuId) {
  return [
    row(menuId + ".rebuild", menuId, {
      icon: "󱁤",
      label: "Rebuild now",
      description: "Asks for the sudo password, then builds in the background",
      action: "nix:rebuild"
    }),
    row(menuId + ".later", menuId, {
      icon: "󰔚",
      label: "Later",
      description: "Keep the change and rebuild when you choose",
      action: "nix:close"
    })
  ]
}

// The one line the menu owns. Marked, so grep and sed reach it and never the
// `enable = true;` lines an app module grows inside its own body.
function markerLine(enabled) {
  return "enable = " + (enabled ? "true" : "false") + "; # Packages menu toggles this"
}

// Registry key and file name for a package attribute: pkgs.gnomeExtensions.foo
// becomes modules/apps/gnomeExtensions-foo.nix holding apps.gnomeExtensions-foo.
function slug(attr) {
  return String(attr || "").replace(/\./g, "-")
}

// A house for the user's own profile, a server for the machine's.
function scopeIcon(scope) {
  return scope === "system" ? "󰒍" : "󰋜"
}

function appsDir(repo) {
  return repo + "/modules/apps"
}

function appFile(repo, name) {
  return appsDir(repo) + "/" + name + ".nix"
}

// `hm` installs a home-manager program option, anything else a nixpkgs
// attribute into the chosen scope.
function template(kind, attr, scope) {
  var target = kind === "hm" ? "home" : scope
  var args = kind === "hm" ? "{ ... }" : "{ pkgs, ... }"
  var body = kind === "hm"
    ? "programs." + attr + ".enable = true;"
    : (target === "home"
      ? "home.packages = [ pkgs." + attr + " ];"
      : "environment.systemPackages = [ pkgs." + attr + " ];")

  return "# " + attr + " - managed by the Packages menu\n"
    + "{\n"
    + "  apps." + slug(attr) + " = {\n"
    + "    " + markerLine(true) + "\n"
    + "    scope = \"" + target + "\";\n"
    + "    module =\n"
    + "      " + args + ":\n"
    + "      {\n"
    + "        " + body + "\n"
    + "      };\n"
    + "  };\n"
    + "}\n"
}

// ------------------------------------------------------------------ commands
//
// Everything that takes a value built from search results is an argv vector, so
// an attribute name is never text a shell re-reads.

function writeArgv(file, content) {
  return ["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"', "bash", file, content]
}

// The marker comment is what makes this safe: the `enable = true;` lines an app
// module carries in its own body do not have it, so they are never touched.
function setEnabledArgv(file, enabled) {
  return ["sed", "-i", "s/" + markerLine(!enabled) + "/" + markerLine(enabled) + "/", file]
}

function quote(value) {
  return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
}

// `nix` is what the build wrote to ~/.config/omarchy-nix.json: the checkout to
// work in, the flake to build and the output name inside it. An empty attr
// leaves it off, so nixos-rebuild falls back to its own default (the hostname).
function rebuildCommand(nix) {
  var flake = nix.flake || ("path:" + nix.repo)
  return "nixos-rebuild switch --flake " + quote(flake + (nix.attr ? "#" + nix.attr : ""))
}

// A terminal is where sudo can prompt and a build can be read. It stays open on
// failure so the error is still there to look at.
function terminalArgv(appId, script, arg) {
  var argv = ["ghostty", "--class=" + appId, "-e", "bash", "-lc",
    script + '\nprintf "\\n[enter to close] "\nread -r _', "bash"]
  return arg === undefined ? argv : argv.concat([arg])
}

// The build itself wants no window: it takes minutes and there is nothing to do
// while it runs. Only the password does, so that is all the terminal is for.
//
// The password reaches the build over the pipe this shell leaves behind - never
// an argument or a variable another process could read - and `setsid` cuts the
// build loose before the window closes. Its own sudo timestamp would not
// survive that (sudo keys the timestamp to the terminal), so the one `sudo -S`
// is the build's own.
function passwordThenRunArgv(jobScript) {
  return ["ghostty", "--class=floating.nixpass", "-e", "bash", "-lc",
    passwordPrompt()
    + 'printf "%s\\n" "$password" | setsid -f bash -c "$1" bash\n',
    "bash", jobScript]
}

// The window exists to ask one thing, so it looks like it: a lock, the question
// under it, the cursor under that, all centered on however wide the terminal
// came up. `stty` rather than `tput`, which needs a terminfo entry for whatever
// TERM the terminal announces.
//
// The window can come up at Ghostty's default size and only then shrink to its
// rule, and Ghostty's reflow strands the cursor (drawn as the lock) away from
// the prompt. So every resize redraws from scratch. Bash holds a WINCH trap
// until `read` returns, hence the short timeout; half-typed input waits in the
// tty's line buffer meanwhile. Echo goes off once, not per `read -s`, so it
// never flickers back on between polls.
function passwordPrompt() {
  var lock = [
    "  ╭─────╮  ",
    "  │     │  ",
    "╭─┴─────┴─╮",
    "│    ●    │",
    "│    ▮    │",
    "╰─────────╯"
  ]

  var script = 'center() { printf "%*s%s\\n" $(( (cols - ${#1}) / 2 )) "" "$1"; }\n'
    + 'draw() {\n'
    + '  cols=$(stty size 2>/dev/null | cut -d" " -f2)\n'
    + '  cols=${cols:-80}\n'
    + '  printf "\\e[H\\e[2J\\n"\n'

  for (var i = 0; i < lock.length; i++) script += '  center "' + lock[i] + '"\n'

  return script
    + '  printf "\\n"\n'
    + '  center "Type password for sudo to rebuild"\n'
    + '  printf "\\n"\n'
    + '  printf "%*s❯ " $(( (cols - 2) / 2 )) ""\n'
    + '}\n'
    + 'stty -echo\n'
    + 'trap draw WINCH\n'
    + 'draw\n'
    + 'password=\n'
    // Ctrl-D or an empty line is a change of mind, not a blank password to
    // hand sudo and then report as a failed build.
    + 'until read -r -t 0.2 chunk; do\n'
    + '  (( $? > 128 )) || exit 0\n'
    + '  password+=$chunk\n'
    + 'done\n'
    + 'password+=$chunk\n'
    + 'trap - WINCH\n'
    + 'stty echo\n'
    + '[[ -n $password ]] || exit 0\n'
    + 'printf "\\n"\n'
}

// Runs detached, as the user: the notification and the log window come from
// here, so a finished build says so wherever the user happens to be looking.
function rebuildJob(nix, pre) {
  return 'cd ' + quote(nix.repo) + ' || exit 1\n'
    + 'log=$(mktemp -t nixos-rebuild-XXXXXX.log)\n'
    // The window is gone by now, so this is the only thing that says the
    // password was taken and the build is on its way.
    + 'send-notification -i hammer "Rebuild started…" '
    + quote((pre ? pre.label + ", then " : "") + "nixos-rebuild switch") + '\n'
    + '{ ' + (pre ? pre.command + " && " : "") + 'sudo -S -p "" ' + rebuildCommand(nix) + '; } >"$log" 2>&1\n'
    + 'status=$?\n'
    + 'if [[ $status -eq 0 ]]; then\n'
    + '  send-notification -i circle-check "Rebuild complete"\n'
    + 'else\n'
    + '  send-notification --type error "Rebuild failed" "exit $status"\n'
    + '  ghostty --class=floating.nixbuild -e bash -lc \'less +G "$1"\' bash "$log"\n'
    + 'fi\n'
}

function rebuildArgv(nix) {
  return passwordThenRunArgv(rebuildJob(nix, null))
}

// No input updates every one. Packages are pinned per input, so one input is
// the smallest unit that can move: `nixpkgs` bumps every nixpkgs package at once.
function updateArgv(nix, input) {
  return passwordThenRunArgv(rebuildJob(nix, input
    ? { command: "nix flake update " + quote(input), label: "update " + input }
    : { command: "nix flake update", label: "flake update" }))
}

// The flake's own inputs from flake.lock, each with the date it is locked at,
// so the list says how stale each one is before picking it.
function inputsScript(repo) {
  return 'jq -r \'.nodes as $n | $n.root.inputs | to_entries[]'
    + ' | select(.value | type == "string") | $n[.value].locked as $l'
    + ' | [.key, .key, "", "locked " + (($l.lastModified // 0) | todate[:10])'
    + ' + (if $l.rev then " · " + $l.rev[:7] else "" end)] | @tsv\' '
    + quote(repo + "/flake.lock") + '\n'
}

function configureArgv(nix, file) {
  return terminalArgv("floating.nixedit",
    'nvim "$1" || exit\nread -rp "Rebuild now? [y/N] " answer\n'
    + "[[ $answer == [yY] ]] && { cd " + quote(nix.repo) + " && sudo " + rebuildCommand(nix) + "; }",
    file)
}

// Apps already on the machine, listed straight from the module files. The
// `enable = true` line is what the whole section toggles, so reading it back is
// what "installed" means here.
function appsScript(repo, enabledOnly) {
  return 'dir=' + quote(appsDir(repo)) + '\n'
    + 'shopt -s nullglob\n'
    + 'for f in "$dir"/*.nix; do\n'
    + '  name=${f##*/}; name=${name%.nix}\n'
    // Where the app installs, as the row's icon and its description: the
    // registry knows it and the name alone never says. A home app is the rule,
    // so system is the one that has to be visible at a glance.
    + '  scope=$(sed -n \'s/.*scope = "\\([a-z]*\\)".*/\\1/p\' "$f" | head -1)\n'
    + '  icon=' + quote(scopeIcon("home")) + '\n'
    + '  [ "$scope" = system ] && icon=' + quote(scopeIcon("system")) + '\n'
    + '  if grep -qF ' + quote(markerLine(true)) + ' "$f"; then printf "%s\\t%s\\t\\t%s\\t%s\\n" "$name" "$name" "$scope" "$icon"\n'
    + (enabledOnly ? '  fi\n' : '  else printf "%s (off)\\t%s\\t\\t%s\\t%s\\n" "$name" "$name" "$scope" "$icon"\n  fi\n')
    + 'done\n'
}

// One pass for the Install list: home-manager program options, nixpkgs
// packages, and what this repo already declares. Tab-separated, kind first.
// The home-manager option names are its module filenames, which is what
// `programs.<name>` is keyed on.
//
// `nix search` walks every attribute on each call (~1s warm, ~13s on a fresh
// revision), so both lists are dumped once and each keystroke greps the dump.
// nixpkgs is keyed by the store path the registry pins, home-manager by
// flake.lock, so a rebuild or flake update gets fresh lists. The lock keeps the
// prewarm run on entering Install and the first query from both dumping. An
// empty query only prepares.
function searchScript(repo) {
  return 'query=$1\n'
    + 'repo=' + quote(repo) + '\n'
    + 'cache=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-packages\n'
    + 'mkdir -p "$cache"\n'
    + 'src=$(nix flake metadata --json nixpkgs 2>/dev/null | jq -r ".path // empty")\n'
    + 'index=$cache/nixpkgs-${src##*/}.tsv\n'
    + 'lock=$(sha1sum "$repo/flake.lock" 2>/dev/null | cut -c1-16)\n'
    + 'programs=$cache/hm-$lock.txt\n'
    + '{\n'
    + '  flock 9\n'
    + '  if [[ -n $src && ! -s $index ]]; then\n'
    + '    nix search nixpkgs --json "^" 2>/dev/null \\\n'
    + '      | jq -r \'to_entries[] | [(.key|sub("^legacyPackages\\\\.[^.]+\\\\.";"")), (.value.version//""), (.value.description//"")] | @tsv\' \\\n'
    + '      >"$index.tmp" && mv "$index.tmp" "$index"\n'
    + '  fi\n'
    + '  if [[ ! -s $programs ]]; then\n'
    + '    hm=$(nix eval --raw --impure --expr "(builtins.getFlake \\"path:$repo\\").inputs.home-manager.outPath" 2>/dev/null)\n'
    + '    [[ -n $hm ]] && ls "$hm/modules/programs" | sed "s/\\.nix$//" >"$programs.tmp" && mv "$programs.tmp" "$programs"\n'
    + '  fi\n'
    + '  for old in "$cache"/nixpkgs-*.tsv "$cache"/hm-*.txt; do\n'
    + '    [[ $old == "$index" || $old == "$programs" ]] || rm -f "$old"\n'
    + '  done\n'
    + '} 9>"$cache/lock"\n'
    + '[[ -n $query ]] || exit 0\n'
    + 'grep -iF -- "$query" "$programs" 2>/dev/null | head -12 | sed "s/^/hm\\t/"\n'
    // Ranked here, not in parseSearch alone: a short query matches thousands,
    // and only the best few may reach the menu. Exact name, prefix, anywhere
    // in the name, then description only; shorter names first within a tier.
    + 'grep -iF -- "$query" "$index" 2>/dev/null \\\n'
    + '  | Q=$query awk -F"\\t" \'BEGIN { q = tolower(ENVIRON["Q"]) }\n'
    + '    { a = tolower($1); t = a == q ? 0 : index(a, q) == 1 ? 1 : index(a, q) ? 2 : 3\n'
    + '      print t "\\t" length($1) "\\tpkg\\t" $0 }\' \\\n'
    + '  | sort -t"\t" -k1,1n -k2,2n | head -60 | cut -f3-\n'
    + 'shopt -s nullglob\n'
    + 'for f in "$repo/modules/apps"/*.nix; do\n'
    + '  name=${f##*/}; name=${name%.nix}\n'
    + '  if grep -qF ' + quote(markerLine(true)) + ' "$f"; then printf "have\\t%s\\t1\\n" "$name"\n'
    + '  else printf "have\\t%s\\t0\\n" "$name"; fi\n'
    + 'done\n'
}

// ---------------------------------------------------------------------- rows

// Lower sorts first: an exact name, then a prefix, then the rest; a
// home-manager option outranks the package of the same name because picking it
// gives the configurable one.
function rank(kind, name, query) {
  var lower = String(name || "").toLowerCase()
  var needle = String(query || "").toLowerCase().trim()
  var tier = lower === needle ? 0 : (lower.indexOf(needle) === 0 ? 2 : 4)

  return tier + (kind === "hm" ? 0 : 1)
}

function parseSearch(text, query, menuId) {
  var lines = String(text || "").split("\n")
  var known = ({})
  var found = []

  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split("\t")
    if (parts[0] === "have") known[parts[1]] = parts[2] === "1"
    else if (parts[0] === "hm" && parts[1]) found.push({ kind: "hm", attr: parts[1], detail: "home-manager option" })
    else if (parts[0] === "pkg" && parts[1]) found.push({
      kind: "pkg",
      attr: parts[1],
      detail: [parts[2], parts[3]].join(" ").trim()
    })
  }

  found.sort(function(a, b) {
    var byRank = rank(a.kind, a.attr, query) - rank(b.kind, b.attr, query)
    if (byRank !== 0) return byRank
    if (a.attr.length !== b.attr.length) return a.attr.length - b.attr.length
    return a.attr.localeCompare(b.attr)
  })

  var rows = []
  var taken = ({})
  for (var j = 0; j < found.length; j++) {
    var pick = found[j]
    var name = slug(pick.attr)
    var installed = known[name]
    var rowId = menuId + "." + pick.kind + "." + name
    if (taken[rowId]) continue
    taken[rowId] = true

    rows.push(row(rowId, menuId, {
      // An app already declared and enabled is listed so the search says so,
      // dimmed because there is nothing to pick. A disabled one is live again:
      // choosing it flips its existing module back on.
      label: pick.attr + (installed === false ? " (disabled)" : ""),
      description: pick.detail,
      icon: pick.kind === "hm" ? "󰒓" : "󰏖",
      action: "nix:install:" + pick.kind + ":" + pick.attr,
      disabledStatic: installed === true
    }))
  }

  // `known` goes back to the caller: installing a name it already carries as
  // false is a flag flip, not a new file.
  return { rows: rows, known: known }
}

function row(id, parent, fields) {
  return {
    id: id,
    parent: parent,
    kind: "action",
    icon: fields.icon || "",
    iconFont: "",
    label: fields.label || id,
    title: "",
    target: "",
    description: fields.description || "",
    action: fields.action || "",
    provider: "",
    aliases: [],
    when: "",
    checked: "",
    disabled: "",
    disabledStatic: !!fields.disabledStatic,
    order: 0
  }
}
