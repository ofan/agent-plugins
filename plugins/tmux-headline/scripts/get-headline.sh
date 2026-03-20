#!/usr/bin/env bash
# For use in tmux #() format strings — outputs headline for the active pane

HEADLINE_DIR="$HOME/.claude/headline"
STATE_FILE="$HEADLINE_DIR/state.json"

[ -f "$STATE_FILE" ] || exit 0

PANE_ID=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
[ -n "$PANE_ID" ] || exit 0

python3 << PYEOF
import json, os

state_file = "$STATE_FILE"
headlines_dir = os.path.expanduser("~/.claude/headline/headlines")
pane_id = "$PANE_ID"

try:
    with open(state_file) as f:
        state = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    exit()

for sid, info in state.items():
    if info.get("pane") == pane_id:
        try:
            with open(os.path.join(headlines_dir, f"{sid}.headline")) as h:
                print(h.read().strip()[:40])
        except FileNotFoundError:
            pass
        break
PYEOF
