#!/usr/bin/env bash
# SessionEnd: clear tmux options and headline file

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Remove headline file
[ -n "$SESSION_ID" ] && rm -f "$HOME/.claude/headline/headlines/${SESSION_ID}.headline"

# Clear tmux options
PANE=$("${PLUGIN_ROOT}/scripts/detect-pane.sh")
if [ -n "$PANE" ]; then
  tmux set-option -p -t "$PANE" -u @pane_headline 2>/dev/null || true
  WINDOW=$(tmux display-message -p -t "$PANE" '#I' 2>/dev/null)
  TMUX_SESSION=$(tmux display-message -p -t "$PANE" '#S' 2>/dev/null)
  [ -n "$WINDOW" ] && [ -n "$TMUX_SESSION" ] && \
    tmux set-option -w -t "${TMUX_SESSION}:${WINDOW}" -u @headline 2>/dev/null || true
fi

echo '{}'
exit 0
