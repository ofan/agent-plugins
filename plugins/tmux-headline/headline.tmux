#!/usr/bin/env bash
# TPM entrypoint — sources automatically via:
#   set -g @plugin 'ofan/tmux-headline'
#
# v1.2+ — Claude drives its own pane_title via the /headline slash command.
# Conditional coloring happens here in the format string (not in the render
# script): @claude_busy=1 → brightyellow; otherwise → dim grey.

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
RENDER="$PLUGIN_DIR/scripts/headline-render.sh"

# Colored render: outer format picks color based on @claude_busy, render
# script outputs plain "<glyph> <text>" with no embedded format codes.
HEADLINE_EXPR="#{?@claude_busy,#[fg=brightyellow],#[fg=colour244]}#($RENDER #{pane_id})#[default]"

tmux set -g status-interval 1

# 1. pane border — show titles in a strip above each pane
if [ "$(tmux show -gv pane-border-status 2>/dev/null)" = "off" ]; then
  tmux set -g pane-border-status top
fi

DEFAULT_BORDER='#{?pane_active,#[reverse],}#P #[default]"#{pane_title}"'
CURRENT_BORDER="$(tmux show -gv pane-border-format 2>/dev/null)"
if [ -z "$CURRENT_BORDER" ] || [ "$CURRENT_BORDER" = "$DEFAULT_BORDER" ]; then
  tmux set -g pane-border-format \
    "#{pane_index} ${HEADLINE_EXPR} #[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"
fi

# 2. window tabs — surface pane_title in the bottom status bar
DEFAULT_WSF='#I:#W#{?window_flags,#{window_flags}, }'
CURRENT_WSF="$(tmux show -gv window-status-format 2>/dev/null)"
if [ -z "$CURRENT_WSF" ] || [ "$CURRENT_WSF" = "$DEFAULT_WSF" ]; then
  tmux set -g window-status-format " #I ${HEADLINE_EXPR} "
fi

CURRENT_WSCF="$(tmux show -gv window-status-current-format 2>/dev/null)"
if [ -z "$CURRENT_WSCF" ] || [ "$CURRENT_WSCF" = "$DEFAULT_WSF" ]; then
  tmux set -g window-status-current-format \
    "#[fg=colour15,bg=colour239,bold] #I ${HEADLINE_EXPR} #[default]"
fi

# 3. allow programs to set pane title via OSC (Claude/Pi/Codex all need this)
tmux set -g allow-rename on
