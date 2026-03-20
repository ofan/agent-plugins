#!/usr/bin/env bash
set -f
# Spinner style: set HEADLINE_SPINNER env var to switch
# Default: claude (Claude's actual yellow braille spinner)
# Alt: flowers (Claude-style star glyphs, small → big → small)
# Alt: braille (clockwise fill and drain)
# Alt: dots (pulsing dot)
STYLE=${HEADLINE_SPINNER:-flowers}
S=$(($(date +%s)))

case "$STYLE" in
  flowers)
    FRAMES=(· ✢ ✽ ✶ ✽ ✢)
    printf '%s' "${FRAMES[$((S % 6))]}"
    ;;
  braille)
    FRAMES=(⠀ ⠁ ⠃ ⠇ ⡇ ⣇ ⣧ ⣷ ⣿ ⣾ ⣼ ⣸ ⢸ ⠸ ⠰ ⠠)
    printf '%s' "${FRAMES[$((S % 16))]}"
    ;;
  dots)
    FRAMES=(· • ● • ·)
    printf '%s' "${FRAMES[$((S % 5))]}"
    ;;
  *)
    FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    printf '%s' "${FRAMES[$((S % 10))]}"
    ;;
esac
