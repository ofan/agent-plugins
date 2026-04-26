#!/usr/bin/env bash
# Render the headline for a tmux pane: cycle through ✳-family glyphs while
# Claude is busy, otherwise passthrough pane_title as-is.
#
# Usage: headline-render.sh <pane_id>
#
# "busy" detection: pane_title starts with a non-alphanumeric glyph followed
# by a space — covers ✳ (Claude's "thinking" OSC) and the single-dot braille
# prefixes Claude writes for other busy states.
#
# Idle markers (✻, leading space, empty, alphanumeric prefix) pass through.
#
# Stop hook is responsible for flipping busy → ✻ on transition (Claude
# doesn't issue an idle OSC sequence on its own).

set -uo pipefail

PANE="${1:-}"
[ -z "$PANE" ] && exit 0

TITLE=$(tmux display-message -p -t "$PANE" '#{pane_title}' 2>/dev/null) || exit 0
[ -z "$TITLE" ] && exit 0

case "$TITLE" in
  # idle / non-glyph prefixes — pass through unchanged
  ''|" "*|✻*|[a-zA-Z0-9]*)
    printf '%s' "$TITLE"
    ;;
  # glyph prefix followed by a space — swap glyph for cycling frame
  *' '*)
    FRAMES=(✳ ✶ ✷ ✺ ✸ ✦)
    GLYPH="${FRAMES[$(date +%s) % ${#FRAMES[@]}]}"
    printf '%s %s' "$GLYPH" "${TITLE#* }"
    ;;
  *)
    # single-glyph or unknown shape — pass through
    printf '%s' "$TITLE"
    ;;
esac
