---
name: tmux-headline
description: Show Claude Code session headlines in tmux window tabs and pane borders. Auto-detects the tmux pane, writes a short task summary after each response, and pushes it to tmux. Requires the tmux-headline Claude Code plugin for hook support.
install: claude plugin marketplace add ofan/claude-plugins && claude plugin install tmux-headline@ofan-plugins
---

# tmux-headline

Shows a 3-6 word summary of what Claude is working on in your tmux window tab and pane border. Updates automatically after each response.

## How it works

1. After each response, Claude writes a short headline to `~/.claude/headline/headlines/{session_id}.headline`
2. The Stop hook detects the tmux pane (via TTY) and sets `@headline` and `@pane_headline` tmux options
3. tmux displays the headline in window tabs and pane borders

## Install

```bash
# Add the marketplace
claude plugin marketplace add ofan/claude-plugins

# Install the plugin
claude plugin install tmux-headline@ofan-plugins
```

Then add to your `~/.tmux.conf`:

```tmux
# Show headline in window tabs (with spinner)
set -g window-status-format " #I #{?#{@headline},#[fg=colour244]#{=18:@headline},#W} "
set -g window-status-current-format "#[fg=colour15,bg=colour239,bold] #I #{?#{@headline},#{=18:@headline},#W} #[default]"
set -g status-interval 1
```
