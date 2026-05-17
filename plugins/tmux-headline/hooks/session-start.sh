#!/usr/bin/env bash
# SessionStart: inject headline-naming instruction into every session.
# Uses additionalContext (silent, not displayed to user).
set -euo pipefail

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "You are in a tmux session with the tmux-headline plugin active. At the start of EVERY session and whenever the workstream changes, you MUST invoke: /headline <2-4 lowercase words>. Name the GOAL or subject, not the user's specific question. Skip meta-instructions (\"tldr\", \"fix it\", \"thanks\") and sub-tasks within the current workstream. Example: user says \"refactor the deepclaude proxy to use litellm\" → /headline deepclaude litellm"
  }
}
EOF
