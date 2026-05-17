#!/usr/bin/env bash
# tmux-headline ticker daemon. Generic sub-second tick driver for tmux state
# that can't be expressed at status-interval cadence (integer seconds only).
# Today it advances @spinner_glyph at 2Hz while any pane has @claude_busy=1;
# the same pattern can drive any future periodic option (countdowns, pulse
# effects, etc.) without re-introducing per-tick forks in the format itself.
#
# Fork-budget design — 2Hz busy / 1Hz idle:
#   busy iteration: 3 forks  (tmux list-panes, tmux set+refresh, sleep)
#   idle iteration: 2 forks  (tmux list-panes, sleep)
# `read -t N </dev/null` was tempting (builtin, no fork) but EOFs immediately
# from /dev/null and spins the loop. /bin/sleep is one fork — accepted.
#
# Cost (8-core box):
#   nothing busy:   ~2 forks/sec → ~0.1% of one core
#   any pane busy:  ~6 forks/sec → ~0.5-1% of one core
#
# Lifecycle: started by headline.tmux which kills the prior PID first, so
# at most one loop per tmux server. Exits when tmux server goes away.

set -uo pipefail

PID_FILE="/tmp/tmux-headline-ticker.${USER}.pid"
TICK_BUSY=0.5    # 2Hz cadence while busy — visible motion without flicker
TICK_IDLE=1      # 1Hz busy-state polling while everyone's idle

FRAMES=(✳ ✶ ✷ ✺ ✸ ✦)
N=${#FRAMES[@]}
i=0

echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

while tmux info >/dev/null 2>&1; do
  # One tmux IPC: enumerate all panes, emit 'x' for each busy one. The
  # case-glob check is a shell builtin (no fork).
  busy=$(tmux list-panes -a -F '#{?#{&&:#{==:#{@claude_busy},1},#{||:#{==:#{pane_current_command},claude},#{||:#{==:#{pane_current_command},codex},#{||:#{==:#{pane_current_command},node},#{==:#{pane_current_command},pi}}}},x,}' 2>/dev/null)
  case "$busy" in
    *x*)
      tmux set -g @spinner_glyph "${FRAMES[i]}" \; refresh-client -S 2>/dev/null
      i=$(( (i + 1) % N ))
      sleep "$TICK_BUSY"
      ;;
    *)
      sleep "$TICK_IDLE"
      ;;
  esac
done
