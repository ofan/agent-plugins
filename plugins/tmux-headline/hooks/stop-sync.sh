#!/usr/bin/env bash
# Stop hook:
#   1. Background polls (cost, usage).
#   2. Clear @claude_busy.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

"${PLUGIN_ROOT}/scripts/usage-poll.sh" &
"${PLUGIN_ROOT}/scripts/cost-poll.sh" &

PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"

if [ -n "$PANE" ]; then
    tmux set-option -p -t "$PANE" @claude_busy 0 2>/dev/null || true
fi

echo '{}'
exit 0