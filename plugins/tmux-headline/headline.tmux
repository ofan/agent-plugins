#!/usr/bin/env bash
# TPM entrypoint — sources automatically via:
#   set -g @plugin 'ofan/tmux-headline'
#
# Headline format colors only the glyph (one char). The text fg is restored
# explicitly after the glyph since tmux's #[default]/push-default/pop-default
# behaves unexpectedly mid-tab (resets to global status-style).

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
RENDER="$PLUGIN_DIR/scripts/headline-render.sh"

# Format expression: glyph in conditional fg + bold, then explicit fg restore
# for the text portion. The caller (each tab format) chooses the text color.
# Note: commas inside #[...] must be escaped as #, when nested in #{?...,...}.
HEADLINE_GLYPH="#{?@claude_busy,#[fg=brightyellow#,bold],#[fg=colour244#,bold]}#($RENDER #{pane_id} glyph)"
HEADLINE_TEXT="#($RENDER #{pane_id} text)"

# Whether @claude_busy is set on this pane (used to opt non-Claude panes —
# Pi, Codex, etc. — out of our styled render and just show pane_title).
CLAUDE_PANE='#{||:#{==:#{@claude_busy},1},#{==:#{@claude_busy},0}}'

tmux set -g status-interval 1

# 1. pane border
if [ "$(tmux show -gv pane-border-status 2>/dev/null)" = "off" ]; then
  tmux set -g pane-border-status top
fi

DEFAULT_BORDER='#{?pane_active,#[reverse],}#P #[default]"#{pane_title}"'
CURRENT_BORDER="$(tmux show -gv pane-border-format 2>/dev/null)"
if [ -z "$CURRENT_BORDER" ] || [ "$CURRENT_BORDER" = "$DEFAULT_BORDER" ]; then
  tmux set -g pane-border-format \
    "#{pane_index} #{?${CLAUDE_PANE},${HEADLINE_GLYPH}#[fg=colour248] ${HEADLINE_TEXT},#{pane_title}} #[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"
fi

# 2. window tabs
DEFAULT_WSF='#I:#W#{?window_flags,#{window_flags}, }'
CURRENT_WSF="$(tmux show -gv window-status-format 2>/dev/null)"
if [ -z "$CURRENT_WSF" ] || [ "$CURRENT_WSF" = "$DEFAULT_WSF" ]; then
  # Inactive tab: status-style is colour248 fg, colour237 bg, no bold.
  # Glyph block set bold; #[default] resets bold and fg to status-style.
  # Non-Claude panes (Pi, Codex) get plain pane_title — preserves their
  # native cycling/static glyphs that we have no business overriding.
  tmux set -g window-status-format " #I #{?${CLAUDE_PANE},${HEADLINE_GLYPH}#[default] ${HEADLINE_TEXT},#{pane_title}} "
fi

CURRENT_WSCF="$(tmux show -gv window-status-current-format 2>/dev/null)"
if [ -z "$CURRENT_WSCF" ] || [ "$CURRENT_WSCF" = "$DEFAULT_WSF" ]; then
  # Active tab: bg=colour239, fg=colour15, bold. Restore fg=colour15 after glyph.
  tmux set -g window-status-current-format \
    "#[fg=colour15,bg=colour239,bold] #I #{?${CLAUDE_PANE},${HEADLINE_GLYPH}#[fg=colour15] ${HEADLINE_TEXT},#{pane_title}} #[default]"
fi

# 3. allow programs to set pane title via OSC
tmux set -g allow-rename on
