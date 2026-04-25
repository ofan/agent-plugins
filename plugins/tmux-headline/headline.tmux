#!/usr/bin/env bash
# TPM entrypoint — sources automatically via:
#   set -g @plugin 'ofan/tmux-headline'
#
# v1.2+ — Claude drives its own pane_title via the sessionTitle hook output.
# This script just enables a pane border that displays that title.
# The plugin no longer overrides window-status-format or other globals
# (see README for an opt-in window-tab snippet).

# Show pane title in a border above each pane (default tmux behavior is "off")
if [ "$(tmux show -gv pane-border-status 2>/dev/null)" = "off" ]; then
  tmux set -g pane-border-status top
fi

# Render: index + pane_title (cyan) + cwd (dim). Only set if user hasn't customized.
DEFAULT_BORDER='#{?pane_active,#[reverse],}#P #[default]"#{pane_title}"'
CURRENT_BORDER="$(tmux show -gv pane-border-format 2>/dev/null)"
if [ -z "$CURRENT_BORDER" ] || [ "$CURRENT_BORDER" = "$DEFAULT_BORDER" ]; then
  tmux set -g pane-border-format \
    "#{pane_index} #[fg=colour90]#{pane_title}#[default] #[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"
fi

# Allow programs to set pane title via OSC (Claude/Pi/Codex all need this)
tmux set -g allow-rename on
