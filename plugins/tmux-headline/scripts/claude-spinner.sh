#!/usr/bin/env bash
# 1Hz cycling spinner for Claude's busy state — used by tmux #() format calls.
# Output is a single glyph from Claude's ✳-family, picked by current second.
# (Braille glyphs are reserved for Pi/Codex panes — they pass through via
# the format's non-Claude branch and show their own pane_title animation.)
FRAMES=(✳ ✶ ✷ ✺ ✸ ✦)
printf '%s' "${FRAMES[$(date +%s) % ${#FRAMES[@]}]}"
