---
name: tmux-headline
description: Show Claude Code session headlines in tmux window tabs and pane borders. Auto-detects the tmux pane, writes a short task summary after each response, and pushes it to tmux. Requires the tmux-headline Claude Code plugin for hook support.
install: claude plugin marketplace add ofan/agent-plugins && claude plugin install tmux-headline@ofan-plugins
---

# tmux-headline

Shows a 3-6 word summary of what Claude is working on in your tmux window tab and pane border. Updates automatically after each response. For Codex, use tmux pane titles plus `~/.codex/config.toml` segment ordering rather than Claude hooks.

## How it works

1. After each response, Claude writes a short headline to `~/.claude/headline/headlines/{session_id}.headline`
2. The Stop hook detects the tmux pane (via TTY) and sets `@headline` and `@pane_headline` tmux options
3. tmux displays the headline in window tabs and pane borders

For Codex, there are no equivalent headline hooks here. The practical integration is:

1. Codex writes `terminal_title`
2. tmux renders `pane_title` for Codex panes
3. Codex's native bottom status bar is configured separately in `~/.codex/config.toml`

## Install

```bash
# Add the marketplace
claude plugin marketplace add ofan/agent-plugins

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
