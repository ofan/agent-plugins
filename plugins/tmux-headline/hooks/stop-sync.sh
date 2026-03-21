#!/usr/bin/env bash
# Stop hook: push headline to tmux + write custom-title to transcript

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Read headline
HEADLINE_FILE="$HOME/.claude/headline/headlines/${SESSION_ID}.headline"
if [ -z "$SESSION_ID" ] || [ ! -f "$HEADLINE_FILE" ]; then echo '{}'; exit 0; fi
HEADLINE=$(head -c 40 "$HEADLINE_FILE" | tr -d '\n')
if [ -z "$HEADLINE" ]; then echo '{}'; exit 0; fi

# Detect pane and push to tmux
PANE=$("${PLUGIN_ROOT}/scripts/detect-pane.sh")
if [ -n "$PANE" ]; then
  WINDOW=$(tmux display-message -p -t "$PANE" '#I' 2>/dev/null)
  TMUX_SESSION=$(tmux display-message -p -t "$PANE" '#S' 2>/dev/null)
  DISPLAY_HEADLINE="${HEADLINE:0:20}"
  tmux set-option -p -t "$PANE" @pane_headline "$DISPLAY_HEADLINE" 2>/dev/null
  [ -n "$WINDOW" ] && [ -n "$TMUX_SESSION" ] && \
    tmux set-option -w -t "${TMUX_SESSION}:${WINDOW}" @headline "$DISPLAY_HEADLINE" 2>/dev/null
fi

# Write headline as Claude session name
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  printf '{"type":"custom-title","customTitle":"%s"}\n' "$HEADLINE" >> "$TRANSCRIPT"
fi

# Poll subscription usage in background
"${PLUGIN_ROOT}/scripts/usage-poll.sh" &

exit 0
