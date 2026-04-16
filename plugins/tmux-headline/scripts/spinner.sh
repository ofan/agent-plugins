#!/usr/bin/env bash
# 1fps braille spinner for tmux #() format strings
# Outputs one frame based on current second
FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
printf '%s' "${FRAMES[$(date +%s) % 10]}"
