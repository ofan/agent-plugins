#!/usr/bin/env bash
# UserPromptSubmit: mark the current pane as busy.
# State lives in a per-pane tmux option @claude_busy and is cleared by Stop.
# This is pure state tracking — no headline computation here.

set -euo pipefail

if [ -n "${TMUX_PANE:-}" ]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_busy 1 2>/dev/null || true
fi

echo '{}'
exit 0
