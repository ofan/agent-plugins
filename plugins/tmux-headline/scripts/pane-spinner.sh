#!/usr/bin/env bash
# Background spinner: cycles braille glyphs in pane_title via tmux select-pane -T.
# Usage: pane-spinner.sh <pane_id> <headline>
# Unified protocol: always uses braille frames.
set -euo pipefail

PANE="$1"
HEADLINE="${2:-}"
PDATA_DIR="$HOME/.local/share/tmux-headline/data"
PIDFILE="$PDATA_DIR/spinner.pid"

[ -z "$PANE" ] && exit 1
[ -z "$HEADLINE" ] && exit 0

echo $$ > "$PIDFILE"

FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
COUNT=${#FRAMES[@]}
I=0
while true; do
  tmux select-pane -t "$PANE" -T "${FRAMES[$((I % COUNT))]} ${HEADLINE}" 2>/dev/null || break
  I=$((I + 1))
  sleep 0.1
done
