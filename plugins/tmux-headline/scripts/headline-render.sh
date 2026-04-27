#!/usr/bin/env bash
# Render a piece of the headline.
# Usage: headline-render.sh <pane_id> [glyph|text]
#   glyph: just the leading glyph (✳-family if busy, ✻ if idle, empty if no glyph in pane_title)
#   text:  just the headline text (pane_title with leading "<glyph> " stripped)
#   (default): "<glyph> <text>" — same as before, no color codes

set -uo pipefail

PANE="${1:-}"
MODE="${2:-full}"
[ -z "$PANE" ] && exit 0

TITLE=$(tmux display-message -p -t "$PANE" '#{pane_title}' 2>/dev/null) || exit 0
[ -z "$TITLE" ] && exit 0

BUSY=$(tmux show-options -p -v -t "$PANE" @claude_busy 2>/dev/null || true)

case "$TITLE" in
  ?' '*) TEXT="${TITLE#* }"; HAS_GLYPH=1 ;;
  *)     TEXT="$TITLE"; HAS_GLYPH=0 ;;
esac

# Plain text (no glyph prefix) → no glyph rendered, text passthrough
if [ "$HAS_GLYPH" = "0" ] || [[ "$TITLE" =~ ^[a-zA-Z0-9] ]]; then
  case "$MODE" in
    glyph) ;;            # nothing
    text)  printf '%s' "$TITLE" ;;
    *)     printf '%s' "$TITLE" ;;
  esac
  exit 0
fi

if [ "$BUSY" = "1" ]; then
  FRAMES=(✳ ✶ ✷ ✺ ✸ ✦)
  GLYPH="${FRAMES[$(date +%s) % ${#FRAMES[@]}]}"
else
  GLYPH="✻"
fi

case "$MODE" in
  glyph) printf '%s' "$GLYPH" ;;
  text)  printf '%s' "$TEXT" ;;
  *)     printf '%s %s' "$GLYPH" "$TEXT" ;;
esac
