#!/usr/bin/env bash
# SessionEnd: remove any residual per-session files.
# (Title state is owned by Claude Code itself now — nothing to clean there.)

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

HEADLINE_DIR="$HOME/.local/share/tmux-headline/headlines"

if [ -n "$SESSION_ID" ]; then
  rm -f "$HEADLINE_DIR/${SESSION_ID}.headline" \
        "$HEADLINE_DIR/${SESSION_ID}.busy" \
        "$HEADLINE_DIR/${SESSION_ID}.pane" \
        "$HEADLINE_DIR/${SESSION_ID}.last_good"
fi

echo '{}'
exit 0
