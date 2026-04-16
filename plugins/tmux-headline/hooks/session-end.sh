#!/usr/bin/env bash
# SessionEnd: kill spinner, clear title, unset @agent

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HOMEDATA="$HOME/.local/share/tmux-headline"
PDATA_DIR="$HOMEDATA/data"
PHEADLINE_DIR="$HOMEDATA/headlines"

# Kill spinner
[ -f "$PDATA_DIR/spinner.pid" ] && kill "$(cat "$PDATA_DIR/spinner.pid")" 2>/dev/null && rm -f "$PDATA_DIR/spinner.pid"

# Load pane
PHEADLINE_DIR="$HOME/.headline/headlines"
PANE_FILE="$PHEADLINE_DIR/${SESSION_ID}.pane"
PANE=$(cat "$PANE_FILE" 2>/dev/null)

if [ -n "$PANE" ]; then
  "$PLUGIN_ROOT/scripts/title.sh" -p "$PANE" ""
  tmux set-option -p -t "$PANE" -u @agent 2>/dev/null || true
fi

# Clean up files
[ -n "$SESSION_ID" ] && rm -f "$PHEADLINE_DIR/${SESSION_ID}.headline" "$PANE_FILE"

echo '{}'
exit 0
