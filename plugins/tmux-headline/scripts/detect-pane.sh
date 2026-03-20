#!/usr/bin/env bash
# Detect the tmux pane for the current process.
# Outputs: pane_id (e.g. %135) or empty string.
# Works even when $TMUX_PANE isn't inherited by hook subprocesses.

if [ -n "$TMUX_PANE" ]; then
  echo "$TMUX_PANE"
  exit 0
fi

TTY=$(python3 -c "
import os
pid = os.getppid()
while pid > 1:
    try:
        fd0 = os.readlink(f'/proc/{pid}/fd/0')
        if '/pts/' in fd0:
            print(fd0); break
    except: pass
    try:
        with open(f'/proc/{pid}/stat') as f:
            pid = int(f.read().split(')')[1].split()[1])
    except: break
" 2>/dev/null)

[ -n "$TTY" ] && tmux list-panes -a -F '#{pane_id} #{pane_tty}' 2>/dev/null | awk -v tty="$TTY" '$2==tty {print $1; exit}'
