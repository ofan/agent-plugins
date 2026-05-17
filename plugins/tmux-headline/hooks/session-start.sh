#!/usr/bin/env bash
# SessionStart: inject headline instruction into every session.
set -euo pipefail
cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "You are in a tmux session. Your current workstream name is shown in the tmux tab. At the start of the session and whenever the workstream genuinely changes, run: bash -c 'mkdir -p ~/.local/share/tmux-headline/headlines && echo \"<2-4 space-separated words>\" > ~/.local/share/tmux-headline/headlines/\"$CLAUDE_SESSION_ID\".headline'. Replace <2-4 space-separated words> with a label describing the current workstream goal. Use spaces, never hyphens. Skip small detours, meta-questions, and follow-ups within the same scope."
  }
}
EOF
