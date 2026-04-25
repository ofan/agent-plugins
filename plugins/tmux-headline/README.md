# tmux-headline

Compresses each turn into a ≤4-word headline and displays it in tmux. Each agent provides its own cycling spinner natively — this plugin just keeps the title text short.

Works with **Claude Code**, **Codex**, and **Pi**.

## v1.2 — how it works

```
User submits prompt:  "fix the overly long claude headlines extra words"
                                         │
plugin's UserPromptSubmit hook compresses ↓ to ≤4 words
                                         │
                          {"sessionTitle": "fix overly long claude"}
                                         │
                  Claude Code applies it (same as /rename)
                                         │
              Claude writes its native cycling pane_title:
                          "✳ fix overly long claude"
                                         │
              tmux's pane-border-format displays #{pane_title}
```

No daemon. No file fight. No 4-word title clobbered by the agent. Each agent keeps its native spinner; the plugin just controls the text.

| Agent | Title source | Spinner |
|-------|--------------|---------|
| Claude | sessionTitle hook output (this plugin) | Claude's native `✳`-family animation |
| Pi | in-process `setInterval` (`extensions/tmux-status.ts`) | Native braille at 100ms |
| Codex | Codex itself | Codex's native frames |

## Install

### 1. tmux (TPM)

```tmux
# ~/.tmux.conf
set -g @plugin 'ofan/tmux-headline'
```

Reload: `prefix + I` (TPM) or `tmux source ~/.tmux.conf`.

Without TPM:

```tmux
run-shell /path/to/tmux-headline/headline.tmux
```

### 2. Agent hooks

**Claude Code:**

```bash
claude plugin install tmux-headline
```

Hooks: `UserPromptSubmit` (emit sessionTitle), `Stop` (background usage poll), `SessionEnd` (cleanup).

**Pi:**

```bash
cp extensions/tmux-status.ts ~/.pi/agent/extensions/
```

**Codex:** works out of the box. Codex writes `pane_title` natively.

## What this plugin sets in tmux

Conservatively, only **two** globals — and each is gated on user defaults:

| Option | Set when | Why |
|--------|----------|-----|
| `pane-border-status` | currently `off` (default) | needed to display the title above each pane |
| `pane-border-format` | currently default/empty | renders `#{pane_title}` with index + cwd |

Plus:

- `allow-rename on` — required for any agent (Claude/Pi/Codex) to set `pane_title` via OSC.

If you have your own `pane-border-format`, the plugin **doesn't touch it**. To opt into the recommended format manually:

```tmux
set -g pane-border-status top
set -g pane-border-format "#{pane_index} #[fg=colour90]#{pane_title}#[default] #[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"
```

For window tabs (opt-in — the plugin will not override your `window-status-format`):

```tmux
set -g window-status-format          " #I #[fg=colour244]#{=24:pane_title}#[default] "
set -g window-status-current-format  "#[fg=colour15,bg=colour239,bold] #I #{pane_title} #[default]"
```

## Files

```
hooks/headline-reminder.sh  UserPromptSubmit — extract ≤4-word title, return sessionTitle
hooks/stop-sync.sh          Stop — background usage poll
hooks/session-end.sh        SessionEnd — cleanup residual files
scripts/extract-headline.sh Transcript-mode extraction (used by Pi)
scripts/spinner.sh          1fps braille frame utility (for tmux #() use)
scripts/usage-poll.sh       Subscription usage poller (cheapest method confirmed: 9 tokens)
scripts/git-status.sh       Git status helper (statusline.js)
extensions/tmux-status.ts   Pi extension (independent codepath)
statusline.js               Rich statusline for Claude/Codex
headline.tmux               TPM entrypoint — sets the two globals (above)
```

## Storage

Plugin state lives in `~/.local/share/tmux-headline/`:

- `data/usage.json` — subscription usage cache (60s throttled)
- `data/spinner.pid` — legacy, removed when seen

Pi continues to use `headlines/<sid>.headline` files; Claude no longer writes there (Claude persists the title in its own session metadata).

## Uninstall

The plugin is intentionally minimal so removal is one-line:

```bash
claude plugin uninstall tmux-headline       # removes hooks
rm -rf ~/.local/share/tmux-headline         # removes state
```

If you added the TPM line manually, remove it from `~/.tmux.conf` and reload.
