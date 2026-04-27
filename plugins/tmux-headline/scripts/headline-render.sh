#!/usr/bin/env bash
# Render the headline for a tmux pane.
# - Busy state (per-pane @claude_busy=1, set by UserPromptSubmit hook):
#   replace any prefix glyph with a 1Hz cycling ✳-family frame.
# - Idle state (@claude_busy=0 or unset, set by Stop hook):
#   replace any prefix glyph with static ✻.
# - No glyph prefix in pane_title (plain text or empty): passthrough.
#
# Busy/idle is determined ONLY from the @claude_busy tmux option, not from
# the prefix glyph in pane_title — Claude's own OSC writes are unreliable
# (continues writing dot-cycle in waiting-for-input mode).

set -uo pipefail

PANE="${1:-}"
[ -z "$PANE" ] && exit 0

TITLE=$(tmux display-message -p -t "$PANE" '#{pane_title}' 2>/dev/null) || exit 0
[ -z "$TITLE" ] && exit 0

# Read the busy flag (set by UserPromptSubmit, cleared by Stop)
BUSY=$(tmux show-options -p -v -t "$PANE" @claude_busy 2>/dev/null || true)

# Identify whether pane_title has a single-glyph + space prefix to strip
case "$TITLE" in
  ?' '*)
    # Detect Unicode (>1 byte) glyph at byte 0 — strip "<glyph> " prefix
    TEXT="${TITLE#* }"
    HAS_GLYPH=1
    ;;
  *)
    TEXT="$TITLE"
    HAS_GLYPH=0
    ;;
esac

if [ "$HAS_GLYPH" = "0" ] || [[ "$TITLE" =~ ^[a-zA-Z0-9] ]]; then
  # Plain text — passthrough
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
