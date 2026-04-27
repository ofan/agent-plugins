#!/usr/bin/env bash
# TPM entrypoint — sources automatically via:
#   set -g @plugin 'ofan/tmux-headline'
#
# The headline is split into two #() calls in the format string:
#   1. glyph piece — colored via #{?@claude_busy,...} conditional
#   2. text piece  — uncolored, uses the format's default style
# This keeps the glyph visually distinct without painting the headline text.

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
RENDER="$PLUGIN_DIR/scripts/headline-render.sh"

# Two #() calls: one for the glyph (colored), one for the text (default style)
HEADLINE_EXPR="#{?@claude_busy,#[fg=brightyellow],#[fg=colour244]}#($RENDER #{pane_id} glyph)#[default] #($RENDER #{pane_id} text)"

tmux set -g status-interval 1

# 1. pane border
if [ "$(tmux show -gv pane-border-status 2>/dev/null)" = "off" ]; then
  tmux set -g pane-border-status top
fi

DEFAULT_BORDER='#{?pane_active,#[reverse],}#P #[default]"#{pane_title}"'
CURRENT_BORDER="$(tmux show -gv pane-border-format 2>/dev/null)"
if [ -z "$CURRENT_BORDER" ] || [ "$CURRENT_BORDER" = "$DEFAULT_BORDER" ]; then
  tmux set -g pane-border-format \
    "#{pane_index} ${HEADLINE_EXPR} #[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"
fi

# 2. window tabs
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

# 3. allow programs to set pane title via OSC
tmux set -g allow-rename on
