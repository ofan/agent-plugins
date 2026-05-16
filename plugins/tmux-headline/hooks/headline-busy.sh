#!/usr/bin/env bash
# UserPromptSubmit hook:
#   1. Set @claude_busy=1 so ticker animates spinner.
#   2. Sync pane_title → @headline (Claude sets pane_title via /headline).
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

# 2. Sync pane_title → @headline
if [ -n "$PANE" ]; then
    TITLE=$(tmux display -p -t "$PANE" '#{pane_title}' 2>/dev/null || true)
    CLEAN=$(echo "$TITLE" | python3 -c "
import sys, re
t = sys.stdin.read().strip()
# Strip leading glyph: ✳ ✻ ✶ ✷ ✺ ✸ ✦ or any braille U+2800-U+28FF
t = re.sub(r'^[✻✳✶✷✺✸✦⠀-⣿]\s*', '', t)
print(t.strip())
" 2>/dev/null)
    if [ -n "$CLEAN" ]; then
        tmux set-option -p -t "$PANE" @headline "$CLEAN" 2>/dev/null || true
    fi
fi

# 3. Guard sessionTitle against degradation
SID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")
CURRENT=$(echo "$INPUT" | python3 -c "import sys,json; print((json.load(sys.stdin).get('session_title') or '').strip())" 2>/dev/null || echo "")
DATA_DIR="$HOME/.local/share/tmux-headline/headlines"

if [ -n "$SID" ]; then
    CUR_WORDS=$(echo "$CURRENT" | wc -w)
    if [ "$CUR_WORDS" -lt 2 ] && [ -f "$DATA_DIR/${SID}.last_good" ]; then
        LAST=$(cat "$DATA_DIR/${SID}.last_good")
        echo "{\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"sessionTitle\":\"$LAST\"}}"
        exit 0
    fi
    if [ "$CUR_WORDS" -ge 2 ]; then
        mkdir -p "$DATA_DIR"
        echo "$CURRENT" > "$DATA_DIR/${SID}.last_good"
    fi
fi

echo '{}'