#!/usr/bin/env bash
# Render the headline for a tmux pane (plain text — outer format handles color).
# - Busy state (@claude_busy=1):  cycling ✳-family glyph + text
# - Idle state (@claude_busy=0):  static ✻ + text
# - Plain pane_title (no glyph prefix): passthrough

set -uo pipefail

PANE="${1:-}"
[ -z "$PANE" ] && exit 0

TITLE=$(tmux display-message -p -t "$PANE" '#{pane_title}' 2>/dev/null) || exit 0
[ -z "$TITLE" ] && exit 0

BUSY=$(tmux show-options -p -v -t "$PANE" @claude_busy 2>/dev/null || true)

case "$TITLE" in
  ?' '*)
    TEXT="${TITLE#* }"
    HAS_GLYPH=1
    ;;
  *)
    TEXT="$TITLE"
    HAS_GLYPH=0
    ;;
esac

if [ "$HAS_GLYPH" = "0" ] || [[ "$TITLE" =~ ^[a-zA-Z0-9] ]]; then
  printf '%s' "$TITLE"
  exit 0
fi

if [ "$BUSY" = "1" ]; then
  FRAMES=(✳ ✶ ✷ ✺ ✸ ✦)
  GLYPH="${FRAMES[$(date +%s) % ${#FRAMES[@]}]}"
  printf '%s %s' "$GLYPH" "$TEXT"
else
  printf '✻ %s' "$TEXT"
fi
