# tmux-headline

Shows a 1-3 word summary of what your coding agent is working on in tmux window tabs and pane borders. Animated braille spinner when busy, static when idle.

Works with **Claude Code**, **Codex**, and **Pi** — all using the same protocol.

## Protocol

Every agent sets its own **pane title** via ANSI escape sequence (`\033]2;...\007`) or `tmux select-pane -T`:

| State | pane_title | Example |
|-------|-----------|---------|
| Busy | `⠋ headline` → cycling braille | `⠋ fix auth bug` → `⠙ fix auth bug` → ... |
| Idle | `⠿ headline` (static) | `⠿ fix auth bug` |
| End | `""` (empty) | |

The agent cycles 10 braille frames at ~200ms when busy. tmux reads `pane_title` directly in its format strings — no custom tmux options needed.

Headlines are also persisted to `~/.local/share/tmux-headline/headlines/{session_id}.headline` for cross-session recovery.

## Install

### 1. tmux (TPM)

```tmux
# ~/.tmux.conf
set -g @plugin 'ofan/tmux-headline'
```

Reload: `prefix + I` to install, or `tmux source ~/.tmux.conf`.

Without TPM, source it directly:

```tmux
run-shell /path/to/tmux-headline/headline.tmux
```

### 2. Agent hooks

**Claude Code** — install the plugin:

```bash
claude plugin install tmux-headline
```

Hooks handle: headline injection (`UserPromptSubmit`), idle sync (`Stop`), cleanup (`SessionEnd`).

**Pi** — copy the extension:

```bash
cp extensions/tmux-status.ts ~/.pi/agent/extensions/
```

Extension handles: headline injection, busy/idle title, cleanup.

**Codex** — works out of the box. Codex sets pane_title natively with its own spinner. The tmux format picks it up automatically.

## How it works

```
Agent writes:  printf '\033]2;⠋ fix auth bug\007'
                  │
tmux reads:    #{pane_title} = "⠋ fix auth bug"  (or "⠿ fix auth bug" when idle)
                  │
Format shows: #{pane_title} directly for agent panes
               else        → #W (window name) for non-agent panes
```

Window tabs show a braille spinner (`⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`) cycling at 1fps when busy. Pane borders show the headline in color.

## Files

```
headline.tmux          TPM entrypoint — sets tmux formats
hooks/                 Claude Code hooks (busy/idle/cleanup)
extensions/            Pi extension (same protocol)
scripts/spinner.sh     1fps braille frame for tmux #()
scripts/detect-pane.sh Pane detection fallback
scripts/usage-poll.sh  Claude subscription usage polling
statusline.js          Rich statusline for Claude/Codex
```
