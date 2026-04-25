---
name: tmux-headline
description: Shows a ≤4-word, heavily compressed headline of what your coding agent is working on in tmux. Claude drives its own native cycling spinner; the plugin just shortens the title.
---

# tmux-headline

Compresses each turn into ≤4 words and lets the agent display it natively in `pane_title` (with whatever cycling spinner the agent already animates). tmux just shows that title.

## v1.2 protocol — Claude

The plugin no longer writes pane_title or runs spinners. It hooks **`UserPromptSubmit`** and returns:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "sessionTitle": "<compressed headline>"
  }
}
```

Claude Code applies this internally (same effect as `/rename`) and continues its own native cycling spinner — `✳ <our short headline>` appears in `pane_title`. No daemon, no file writes, no race.

Idempotent: hook input includes the current `session_title`; we no-op if unchanged.

## Pi (unchanged)

Pi extension still runs in-process at `extensions/tmux-status.ts:151` with a 100ms `setInterval` braille spinner. The Pi side owns its own `pane_title` writes; this plugin's Claude-side changes don't affect it.

## Codex (unchanged)

Codex writes `pane_title` natively. tmux's `pane-border-format` reads it directly.

## Install

1. Add `set -g @plugin 'ofan/tmux-headline'` to `~/.tmux.conf` (TPM)
2. Install agent hooks: `claude plugin install tmux-headline`
3. For Pi: `cp extensions/tmux-status.ts ~/.pi/agent/extensions/`
