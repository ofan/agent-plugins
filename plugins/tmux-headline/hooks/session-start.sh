#!/usr/bin/env bash
# SessionStart: inject headline instruction into every session.
set -euo pipefail
cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "BEFORE responding to the user, run this exact bash command to set the tmux headline: bash -c 'mkdir -p ~/.local/share/tmux-headline/headlines && echo \"2-4 lowercase words\" > ~/.local/share/tmux-headline/headlines/\"$CLAUDE_SESSION_ID\".headline && tmux set-option -p -t \"$TMUX_PANE\" @headline \"2-4 lowercase words\" && tmux select-pane -t \"$TMUX_PANE\" -T \"2-4 lowercase words\"'. Replace the 2-4 lowercase words with a label for the workstream GOAL. Do this FIRST, before any other tool call. Update the headline whenever the workstream genuinely changes. Use spaces, never hyphens."
  }
}
EOF
