#!/usr/bin/env bash
# Stop hook:
#   1. Background usage poll (throttled).
#   2. Clear the @claude_busy flag on this pane so the renderer stops cycling.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Background usage poll (throttled to once per 60s inside the script)
"${PLUGIN_ROOT}/scripts/usage-poll.sh" &

# Mark pane idle. Per-pane tmux option — Claude's pane_title rewrites can't clobber it.
if [ -n "${TMUX_PANE:-}" ]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_busy 0 2>/dev/null || true
fi

echo '{}'
exit 0
