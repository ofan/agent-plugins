#!/usr/bin/env bash
# Set pane title.
# Usage: title.sh [-p pane_id] "title text"
# Tries: /dev/tty escape → tmux select-pane
PANE=""
while getopts "p:" opt; do
  case $opt in p) PANE="$OPTARG" ;; esac
done
shift $((OPTIND - 1))
TITLE="$1"

# 1. Direct escape to controlling terminal
if printf '\033]2;%s\007' "$TITLE" >/dev/tty 2>/dev/null; then
  exit 0
fi

# 2. Explicit pane, or TMUX_PANE, or detect
if [ -z "$PANE" ]; then
  PANE="${TMUX_PANE:-}"
fi
if [ -z "$PANE" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PANE=$("$SCRIPT_DIR/detect-pane.sh" 2>/dev/null)
fi

[ -n "$PANE" ] && tmux select-pane -t "$PANE" -T "$TITLE" 2>/dev/null
