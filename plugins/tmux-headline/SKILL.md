# tmux-headline

Shows a 1-3 word summary of what your coding agent is working on in tmux window tabs and pane borders. Animated braille spinner when busy, static when idle.

## Protocol

Headlines are extracted automatically from conversation transcripts by hook scripts — agents don't need to do anything. The hooks/extension set pane_title via escape sequences or `tmux select-pane -T`:

- **Busy**: `⠋ headline` → cycling braille (⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ at ~200ms)
- **Idle**: `⠿ headline` (static)
- **End**: `""` (cleared)

tmux format strings read `pane_title` directly — no custom options, no CLI calls needed for display.

## Install

1. Add `set -g @plugin 'ofan/tmux-headline'` to `~/.tmux.conf` (TPM)
2. Install agent hooks: `claude plugin install tmux-headline`
3. For Pi: `cp extensions/tmux-status.ts ~/.pi/agent/extensions/`
4. Codex works out of the box
