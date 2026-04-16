#!/usr/bin/env bash
# TPM entrypoint — sources automatically via:
#   set -g @plugin 'ofan/tmux-headline'
#
# Detection: @agent pane option (set by hooks/extension)
#            or pane_current_command = node (Codex)
#
# Agent panes show pane_title (agents manage their own spinner + headline).
# Other panes show #W (window name).

# Window tabs
tmux set -g window-status-format \
  " #I #{?#{||:#{@agent},#{==:#{pane_current_command},node}},#[fg=colour244]#{=24:pane_title}#[default],#W} "

tmux set -g window-status-current-format \
  "#[fg=colour15,bg=colour239,bold] #I #{?#{||:#{@agent},#{==:#{pane_current_command},node}},#{pane_title},#W} #[default]"

tmux set -g status-interval 1

# Pane borders
tmux set -g pane-border-status top
tmux set -g pane-border-format \
  "#{pane_index} #{?#{@agent},#[fg=colour90]#{pane_title}#[default] ,}#[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"

# Allow programs to set pane title
tmux set -g allow-rename on
