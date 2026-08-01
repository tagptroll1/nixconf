#!/usr/bin/env bash
# Godot external editor shim. Reuse an nvim already cwd'd in the project, else new window.
# Godot calls: godot-nvim.sh {project} {file} {line} {col}
project=$1 file=$2 line=${3:-1} col=${4:-1}

for sock in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/nvim.*; do
	[ -S "$sock" ] || continue
	# stale sockets outlive their process; timeout instead of hanging
	cwd=$(timeout 1 nvim --server "$sock" --remote-expr 'getcwd()' 2>/dev/null) || continue
	case "$cwd/" in
	"$project"/*)
		nvim --server "$sock" --remote "$file"
		nvim --server "$sock" --remote-send "<C-\\><C-N>:call cursor($line,$col)<CR>"
		exit 0
		;;
	esac
done

exec ghostty -e nvim "+call cursor($line, $col)" "$file"
