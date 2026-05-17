#!/usr/bin/env bash
# UserPromptSubmit hook:
#   1. Set @claude_busy=1 so ticker animates spinner.
#   2. Sync session_title → @headline (single source of truth).
#   3. Sync @headline → pane_title (for border display).
#   4. Guard against degradation (single-word titles).
set -euo pipefail

INPUT=$(cat)

# 1. Mark pane busy
PANE="${TMUX_PANE:-}"
if [ -z "$PANE" ]; then
    PANE=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)
fi
if [ -n "$PANE" ]; then
    tmux set-option -p -t "$PANE" @claude_busy 1 2>/dev/null || true
fi

# 2 & 3. Sync session_title → @headline → pane_title
TITLE=$(echo "$INPUT" | python3 -c "import sys,json; print((json.load(sys.stdin).get('session_title') or '').strip())" 2>/dev/null || echo "")
SID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")

# Persist and guard against degradation
DATA_DIR="$HOME/.local/share/tmux-headline/headlines"
WORDS=$(echo "$TITLE" | wc -w)

if [ "$WORDS" -lt 2 ] && [ -n "$SID" ] && [ -f "$DATA_DIR/${SID}.last_good" ]; then
    TITLE=$(cat "$DATA_DIR/${SID}.last_good")
elif [ "$WORDS" -ge 2 ] && [ -n "$SID" ]; then
    mkdir -p "$DATA_DIR"
    echo "$TITLE" > "$DATA_DIR/${SID}.last_good"
fi

if [ -n "$TITLE" ] && [ -n "$PANE" ]; then
    tmux set-option -p -t "$PANE" @headline "$TITLE" 2>/dev/null || true
    tmux select-pane -t "$PANE" -T "$TITLE" 2>/dev/null || true
fi

echo '{}'