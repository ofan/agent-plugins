#!/usr/bin/env bash
# TPM entrypoint — sources automatically via:
#   set -g @plugin 'ofan/tmux-headline'
#
# v1.2+ — Claude drives its own pane_title via the sessionTitle hook output.
# This script enables a pane border + window tabs that surface that title,
# but only overrides options that are still at tmux's default value, so
# user customizations are preserved.

# 1. pane border — show titles in a strip above each pane
if [ "$(tmux show -gv pane-border-status 2>/dev/null)" = "off" ]; then
  tmux set -g pane-border-status top
fi

DEFAULT_BORDER='#{?pane_active,#[reverse],}#P #[default]"#{pane_title}"'
CURRENT_BORDER="$(tmux show -gv pane-border-format 2>/dev/null)"
if [ -z "$CURRENT_BORDER" ] || [ "$CURRENT_BORDER" = "$DEFAULT_BORDER" ]; then
  tmux set -g pane-border-format \
    "#{pane_index} #[fg=colour90]#{pane_title}#[default] #[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"
fi

# 2. window tabs — surface pane_title in the bottom status bar
DEFAULT_WSF='#I:#W#{?window_flags,#{window_flags}, }'
CURRENT_WSF="$(tmux show -gv window-status-format 2>/dev/null)"
if [ -z "$CURRENT_WSF" ] || [ "$CURRENT_WSF" = "$DEFAULT_WSF" ]; then
  tmux set -g window-status-format \
    " #I #[fg=colour244]#{=24:pane_title}#[default] "
fi

CURRENT_WSCF="$(tmux show -gv window-status-current-format 2>/dev/null)"
if [ -z "$CURRENT_WSCF" ] || [ "$CURRENT_WSCF" = "$DEFAULT_WSF" ]; then
  tmux set -g window-status-current-format \
    "#[fg=colour15,bg=colour239,bold] #I #{pane_title} #[default]"
fi

# 3. allow programs to set pane title via OSC (Claude/Pi/Codex all need this)
tmux set -g allow-rename on
