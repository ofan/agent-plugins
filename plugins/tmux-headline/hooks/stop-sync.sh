#!/usr/bin/env bash
# Stop hook: extract headline, set idle title (⠿ headline).

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HOMEDATA="$HOME/.local/share/tmux-headline"
PDATA_DIR="$HOMEDATA/data"
HEADLINE_DIR="$HOMEDATA/headlines"

# Kill any leftover background spinner
PIDFILE="$PDATA_DIR/spinner.pid"
[ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null && rm -f "$PIDFILE"

# Load pane
PANE_FILE="$HEADLINE_DIR/${SESSION_ID}.pane"
PANE=$(cat "$PANE_FILE" 2>/dev/null)

[ -z "$PANE" ] && { echo '{}'; exit 0; }

# Read existing headline
HEADLINE_FILE="$HEADLINE_DIR/${SESSION_ID}.headline"
HEADLINE=""
[ -f "$HEADLINE_FILE" ] && HEADLINE=$(head -c 40 "$HEADLINE_FILE" | tr -d '\n')

# Extract fresh headline from transcript
if [ -n "$TRANSCRIPT" ]; then
  NEW=$("$PLUGIN_ROOT/scripts/extract-headline.sh" "$TRANSCRIPT" "$HEADLINE" 2>/dev/null) || true
  if [ -n "$NEW" ]; then
    HEADLINE="$NEW"
    echo "$HEADLINE" > "$HEADLINE_FILE"
  fi
fi

# Set idle title: ⠿ headline
if [ -n "$HEADLINE" ]; then
  "$PLUGIN_ROOT/scripts/title.sh" -p "$PANE" "⠿ $HEADLINE"
else
  # Clear to just the idle glyph if no headline yet
  "$PLUGIN_ROOT/scripts/title.sh" -p "$PANE" "⠿"
fi

# Write headline as Claude session name (for session list UI)
if [ -n "$HEADLINE" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  printf '{"type":"custom-title","customTitle":"%s"}\n' "$HEADLINE" >> "$TRANSCRIPT"
fi

# Poll subscription usage in background
"${PLUGIN_ROOT}/scripts/usage-poll.sh" &

echo '{}'
exit 0
