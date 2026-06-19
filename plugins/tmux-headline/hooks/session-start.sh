#!/usr/bin/env bash
# SessionStart: (1) keep the tmux stable symlink pointed at the running plugin
# version so headline.tmux tracks `claude plugin update` automatically, and
# (2) inject the headline-naming instruction into the session.
set -euo pipefail

# (1) Auto-heal the stable symlink. Silent — hook stdout is parsed as JSON, so
# nothing here may print. $CLAUDE_PLUGIN_ROOT is the current cache version dir
# (the git-repo-sourced copy). ~/.tmux.conf references the stable symlink path,
# so re-pointing it here is enough to pick up the new headline.tmux on the next
# `tmux source ~/.tmux.conf`.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  link="${HOME}/.tmux/plugins/tmux-headline"
  mkdir -p "$(dirname "$link")" 2>/dev/null || true
  cur=""
  [ -L "$link" ] && cur="$(readlink "$link" 2>/dev/null || true)"
  if [ "$cur" != "$CLAUDE_PLUGIN_ROOT" ]; then
    ln -sfn "$CLAUDE_PLUGIN_ROOT" "$link" 2>/dev/null || true
  fi
fi

# (2) Inject headline instruction. This stdout IS the hook's JSON payload.
cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "BEFORE responding to the user, run this exact bash command to set the tmux headline: bash -c 'mkdir -p ~/.local/share/tmux-headline/headlines && echo \"2-4 lowercase words\" > ~/.local/share/tmux-headline/headlines/\"$CLAUDE_SESSION_ID\".headline && tmux set-option -p -t \"$TMUX_PANE\" @headline \"2-4 lowercase words\" && tmux select-pane -t \"$TMUX_PANE\" -T \"2-4 lowercase words\"'. Replace the 2-4 lowercase words with a label for the workstream GOAL. Do this FIRST, before any other tool call. Update the headline whenever the workstream genuinely changes. Use spaces, never hyphens."
  }
}
EOF
