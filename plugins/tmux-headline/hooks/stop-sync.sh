#!/usr/bin/env bash
# Stop hook:
#   1. Background usage poll (throttled).
#   2. Flip pane_title's busy glyph to ✻ so the tmux render-script knows
#      Claude is idle. (Claude doesn't issue an idle OSC sequence on its
#      own — the busy ✳/braille prefix would otherwise stay stuck.)
#
# Title management is otherwise delegated to /headline + the naming skill.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Background usage poll (throttled to once per 60s inside the script)
"${PLUGIN_ROOT}/scripts/usage-poll.sh" &

# Flip busy glyph → ✻ so render-script stops cycling. Best-effort.
PANE="${TMUX_PANE:-}"
if [ -n "$PANE" ]; then
  TITLE=$(tmux display-message -p -t "$PANE" '#{pane_title}' 2>/dev/null || true)
  case "$TITLE" in
    ''|" "*|✻*|[a-zA-Z0-9]*) ;; # already idle / no glyph prefix — leave alone
    *' '*) tmux select-pane -t "$PANE" -T "✻ ${TITLE#* }" 2>/dev/null || true ;;
  esac
fi

echo '{}'
exit 0
