#!/usr/bin/env bash
# Render the headline for a tmux pane WITH embedded format codes — must be
# wrapped in #{E:...} in the format string so tmux evaluates them.
#
# Output: <colored-glyph> <text-in-default-format>
# - Busy (@claude_busy=1): brightyellow cycling glyph + reset color for text
# - Idle (@claude_busy=0): colour244 dim ✻ + reset color for text
# - Plain pane_title (no glyph prefix): passthrough as-is (no codes)

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
  # brightyellow glyph, reset to default style for the text
  printf '#[fg=brightyellow]%s#[default] %s' "$GLYPH" "$TEXT"
else
  # dim grey ✻, reset for text
  printf '#[fg=colour244]✻#[default] %s' "$TEXT"
fi
