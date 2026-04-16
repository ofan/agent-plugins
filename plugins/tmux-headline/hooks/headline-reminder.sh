#!/usr/bin/env bash
# UserPromptSubmit: detect pane, set up tmux formats, set busy title.
# Runs every time the user sends a message — marks the pane as busy.

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

if [ -z "$SESSION_ID" ]; then
  echo '{}'
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HOMEDATA="$HOME/.local/share/tmux-headline"
PDATA_DIR="$HOMEDATA/data"
HEADLINE_DIR="$HOMEDATA/headlines"
mkdir -p "$HEADLINE_DIR"

# Detect and persist pane ID
PANE_FILE="$HEADLINE_DIR/${SESSION_ID}.pane"
if [ ! -f "$PANE_FILE" ]; then
  PANE="${TMUX_PANE:-$("$PLUGIN_ROOT/scripts/detect-pane.sh" 2>/dev/null)}"
  [ -n "$PANE" ] && echo "$PANE" > "$PANE_FILE"
fi
PANE=$(cat "$PANE_FILE" 2>/dev/null)

[ -z "$PANE" ] && { echo '{}'; exit 0; }

# One-time tmux format setup (idempotent)
if ! tmux show -gv @headline_ready 2>/dev/null | grep -q 1; then
  bash "$PLUGIN_ROOT/headline.tmux" 2>/dev/null
  tmux set -g @headline_ready 1 2>/dev/null
fi

# Mark as agent pane
tmux set-option -p -t "$PANE" @agent 1 2>/dev/null || true

# Set busy title with existing headline (if any), or just spinner
HEADLINE_FILE="$HEADLINE_DIR/${SESSION_ID}.headline"
HEADLINE=""
[ -f "$HEADLINE_FILE" ] && HEADLINE=$(head -c 40 "$HEADLINE_FILE" | tr -d '\n')

if [ -n "$HEADLINE" ]; then
  "$PLUGIN_ROOT/scripts/title.sh" -p "$PANE" "⠋ $HEADLINE"
else
  "$PLUGIN_ROOT/scripts/title.sh" -p "$PANE" "⠋"
fi

echo '{}'
exit 0
