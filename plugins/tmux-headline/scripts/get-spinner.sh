#!/usr/bin/env bash
# Animated spinner for Claude windows in tmux status bar
# Idle (✳ in pane title) → static dot
# Busy (braille dots) → animated spinner cycling on the second
PANE=${1:-$(tmux display-message -p '#{pane_id}')}
TITLE=$(tmux display-message -p -t "$PANE" '#{pane_title}' 2>/dev/null)
FIRST=$(printf '%.1s' "$TITLE")
if [ "$FIRST" = "✳" ]; then
  echo "·"
else
  FRAMES=('-' '\' '|' '/')
  echo "${FRAMES[$(date +%s) % 4]}"
fi
