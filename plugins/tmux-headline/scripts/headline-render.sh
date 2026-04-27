#!/usr/bin/env bash
# Render the headline for a tmux pane.
# - Busy state (per-pane @claude_busy=1, set by UserPromptSubmit hook):
#   replace any prefix glyph with a 1Hz cycling ✳-family frame in
#   bright yellow.
# - Idle state (@claude_busy=0 or unset, set by Stop hook):
#   replace any prefix glyph with static ✻ in dim grey.
# - No glyph prefix in pane_title (plain text or empty): passthrough.
#
# Busy/idle is determined ONLY from the @claude_busy tmux option, not from
# the prefix glyph in pane_title.

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
  printf '#[fg=brightyellow]%s#[default] %s' "$GLYPH" "$TEXT"
else
  printf '#[fg=colour244]✻#[default] %s' "$TEXT"
fi
