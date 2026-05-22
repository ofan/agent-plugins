#!/usr/bin/env bash
# TPM entrypoint — sources automatically via:
#   set -g @plugin 'ofan/tmux-headline'
#
# Daemon-driven spinner edition. Format reads #{@spinner_glyph} (zero forks
# per status tick) and a background loop updates that option at 2Hz while
# any pane has @claude_busy=1. tmux's status-interval is integer-seconds
# only, so faster animation needs an external ticker; #() inside formats
# would re-introduce per-tick fork costs.
#
# Cost: ~0.3% of one core when nothing is busy (1 IPC/sec poll), ~1.5% while
# busy (2Hz set+refresh). See scripts/spinner-loop.sh for the loop itself.

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colored glyph block:
#  - busy → bright yellow bold + #{@spinner_glyph} (updated by spinner-loop.sh).
#    Falls back to a literal ✳ if the daemon hasn't ticked yet so the format
#    never renders empty.
#  - idle → dim + bold static ✻.
# Note: commas inside #[...] must be escaped as #, whenever the block is
# consumed inside a #{?cond,then,else} expression.
GLYPH_BUSY='#[fg=brightyellow#,bold]#{?@spinner_glyph,#{@spinner_glyph},✳}'
GLYPH_IDLE='#[fg=colour244#,bold]✻'
GLYPH_BLOCK="#{?#{==:#{@claude_busy},1},${GLYPH_BUSY},${GLYPH_IDLE}}"

# pane_title with leading "<glyph-or-word> " prefix stripped (BRE: any
# non-space sequence followed by space). Only used for Claude panes that don't
# have @headline set yet — Claude writes "✳ ..." into pane_title.
TITLE_TEXT='#{s/^[^ ][^ ]* //:#{pane_title}}'

# Whether this pane is a Claude pane (@claude_busy is 0 or 1).
CLAUDE_PANE='#{||:#{==:#{@claude_busy},1},#{==:#{@claude_busy},0}}'

# Whether this pane is a non-Claude agent (Pi, Codex). Used for fallback
# rendering when @headline isn't set — these agents manage pane_title themselves.
# Uses pane_current_command (no fnmatch bracket expressions, no byte-range bugs).
AGENT_PANE='#{||:#{||:#{==:#{pane_current_command},pi},#{==:#{pane_current_command},codex}},#{==:#{pane_current_command},node}}'

# Two variants: @headline first, then Claude pane fallback (glyph + stripped
# title), then other agent passthrough (pane_title as-is), then window name.
HEADLINE_INACTIVE="#{?#{@headline},${GLYPH_BLOCK}#[default] #{=24:#{@headline}}#[default],#{?${CLAUDE_PANE},${GLYPH_BLOCK}#[default] ${TITLE_TEXT}#[default],#{?${AGENT_PANE},#{pane_title},#W}}}"
HEADLINE_ACTIVE="#{?#{@headline},${GLYPH_BLOCK}#[fg=colour15] #{=24:#{@headline}}#[default],#{?${CLAUDE_PANE},${GLYPH_BLOCK}#[fg=colour15] ${TITLE_TEXT}#[default],#{?${AGENT_PANE},#{pane_title},#W}}}"

# Recognize formats produced by any prior version of this plugin so re-running
# `headline.tmux` (e.g. on upgrade) reliably swaps in the current version.
# Patterns:
#   1. v1.2.x and earlier: #(headline-render.sh ...) shell calls.
#   2. v1.3.x glyph-based: uses fnmatch bracket [⠁-⣿✻✳✶✷✺✸✦⠿] for HAS_GLYPH.
#   3. v1.5.x @headline-based: uses @headline option for agent-driven titles.
is_legacy() {
  case "$1" in
    *headline-render.sh*)        return 0 ;;
    *'[⠁-⣿✻✳✶✷✺✸✦⠿]'*)           return 0 ;;
    *@headline*)                 return 0 ;;
    *)                           return 1 ;;
  esac
}

tmux set -g status-interval 1

# 1. pane border
if [ "$(tmux show -gv pane-border-status 2>/dev/null)" = "off" ]; then
  tmux set -g pane-border-status top
fi

DEFAULT_BORDER='#{?pane_active,#[reverse],}#P #[default]"#{pane_title}"'
CURRENT_BORDER="$(tmux show -gv pane-border-format 2>/dev/null)"
if [ -z "$CURRENT_BORDER" ] || [ "$CURRENT_BORDER" = "$DEFAULT_BORDER" ] || is_legacy "$CURRENT_BORDER"; then
  tmux set -g pane-border-format \
    "#{pane_index} ${HEADLINE_INACTIVE} #[fg=cyan]#{session_name}#[default] #[fg=green]#[bold]\$#{?@cost_total,#{@cost_total},0.00}#[default] #[dim]#{b:pane_current_path}#[default]"
fi

# 2. window tabs
DEFAULT_WSF='#I:#W#{?window_flags,#{window_flags}, }'

CURRENT_WSF="$(tmux show -gv window-status-format 2>/dev/null)"
if [ -z "$CURRENT_WSF" ] || [ "$CURRENT_WSF" = "$DEFAULT_WSF" ] || is_legacy "$CURRENT_WSF"; then
  tmux set -g window-status-format " #I ${HEADLINE_INACTIVE} "
fi

CURRENT_WSCF="$(tmux show -gv window-status-current-format 2>/dev/null)"
if [ -z "$CURRENT_WSCF" ] || [ "$CURRENT_WSCF" = "$DEFAULT_WSF" ] || is_legacy "$CURRENT_WSCF"; then
  tmux set -g window-status-current-format \
    "#[fg=colour15,bg=colour239,bold] #I ${HEADLINE_ACTIVE} #[default]"
fi

# 3. allow programs to set pane title via OSC
tmux set -g allow-rename on

# 4. start (or restart) the ticker daemon — drives @spinner_glyph at 2Hz so
# tmux can animate sub-second despite status-interval being integer-seconds.
# Idempotent: catch any stragglers by full path (PID file alone misses orphans
# left over from previous installs that crashed without removing their pidfile).
TICKER="$PLUGIN_DIR/scripts/tmux-headline-ticker.sh"
TICKER_PID="/tmp/tmux-headline-ticker.${USER}.pid"
pkill -f "$TICKER" 2>/dev/null || true
rm -f "$TICKER_PID"
if [ -x "$TICKER" ]; then
  nohup "$TICKER" >/dev/null 2>&1 &
  disown 2>/dev/null || true
fi
