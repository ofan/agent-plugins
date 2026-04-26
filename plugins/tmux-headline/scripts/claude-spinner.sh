#!/usr/bin/env bash
# 1Hz cycling spinner for Claude's busy state — used by tmux #() format calls.
# Output is a single glyph from Claude's ✳-family, picked by current second.
FRAMES=(✳ ✶ ✷ ✺ ✸ ✦)
printf '%s' "${FRAMES[$(date +%s) % ${#FRAMES[@]}]}"
