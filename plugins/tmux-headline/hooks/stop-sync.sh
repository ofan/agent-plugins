#!/usr/bin/env bash
# Stop hook:
#   1. Background polls (cost, usage).
#   2. Clear @claude_busy.
#   3. Sync pane_title → @headline (Claude may have called /headline).
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

"${PLUGIN_ROOT}/scripts/usage-poll.sh" &
"${PLUGIN_ROOT}/scripts/cost-poll.sh" &

PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"

if [ -n "$PANE" ]; then
    tmux set-option -p -t "$PANE" @claude_busy 0 2>/dev/null || true

    # Sync pane_title → @headline (picks up /headline changes)
    TITLE=$(tmux display -p -t "$PANE" '#{pane_title}' 2>/dev/null || true)
    CLEAN=$(echo "$TITLE" | python3 -c "
import sys, re
t = sys.stdin.read().strip()
t = re.sub(r'^[✻✳✶✷✺✸✦⠀-⣿]\s*', '', t)
print(t.strip())
" 2>/dev/null)
    if [ -n "$CLEAN" ]; then
        tmux set-option -p -t "$PANE" @headline "$CLEAN" 2>/dev/null || true
    fi
fi

echo '{}'
exit 0