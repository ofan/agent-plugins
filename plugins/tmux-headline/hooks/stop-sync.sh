#!/usr/bin/env bash
# Stop hook:
#   1. Background usage/cost polls (throttled).
#   2. Clear @claude_busy on this pane so spinner stops.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Background polls (throttled internally)
"${PLUGIN_ROOT}/scripts/usage-poll.sh" &
"${PLUGIN_ROOT}/scripts/cost-poll.sh" &

# Detect pane — TMUX_PANE not inherited, use display-message
PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"
if [ -n "$PANE" ]; then
    tmux set-option -p -t "$PANE" @claude_busy 0 2>/dev/null || true
fi

echo '{}'
exit 0
