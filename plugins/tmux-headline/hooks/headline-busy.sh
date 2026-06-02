#!/usr/bin/env bash
# UserPromptSubmit hook:
#   1. Set @claude_busy=1 for spinner.
#   2. Read headline from file (Claude writes it), sync to @headline.
set -euo pipefail

INPUT=$(cat)

# 1. Mark busy
PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"
if [ -n "$PANE" ]; then
  tmux set-option -p -t "$PANE" @claude_busy 1 2>/dev/null || true
fi

# 2. Read headline from file → @headline (only if not already set — preserves
#    mid-response renames that the agent made via tmux directly)
EXISTING=$(tmux show-options -p -v -t "$PANE" @headline 2>/dev/null || true)
if [ -z "$EXISTING" ]; then
  SID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")
  HEADLINE_FILE="$HOME/.local/share/tmux-headline/headlines/${SID}.headline"
  if [ -n "$SID" ] && [ -f "$HEADLINE_FILE" ] && [ -n "$PANE" ]; then
    HEADLINE=$(cat "$HEADLINE_FILE")
    if [ -n "$HEADLINE" ]; then
      tmux set-option -p -t "$PANE" @headline "$HEADLINE" 2>/dev/null || true
      tmux select-pane -t "$PANE" -T "$HEADLINE" 2>/dev/null || true
    fi
  fi
fi

echo '{}'
