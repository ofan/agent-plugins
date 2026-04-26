# tmux-headline

Compresses each workstream into a ≤4-word headline displayed in tmux. Claude itself decides when to update via the `/headline` slash command — guided by an included naming skill.

Works with **Claude Code**, **Codex**, and **Pi**.

## v1.2.3 — how it works

```
Claude observes a workstream shift (or session start, or recap)
                  │
                  ▼
   skill: headline-naming triggers Claude to call /headline
                  │
                  ▼
       /headline auth service deploy   ← visible tool call
                  │
                  ▼
   command body runs:  tmux select-pane -T "auth service deploy"
                  │
                  ▼
   pane_title becomes "auth service deploy"
                  │
                  ▼
   tmux renders it in pane border + (optional) window tabs
```

No daemon, no UserPromptSubmit hook for headline, no API calls, no race with Claude's auto-summary. Claude proactively names its own workstream — and the call shows up in the transcript so you can audit and correct it.

| Agent | Headline source | Spinner |
|-------|-----------------|---------|
| Claude | `/headline` slash command (this plugin) + skill prompting | Claude's native `✳`-family animation |
| Pi | in-process `setInterval` (`extensions/tmux-status.ts`) | Native braille at 100ms |
| Codex | Codex itself | Codex's native frames |

## Install

### 1. tmux (TPM)

```tmux
set -g @plugin 'ofan/tmux-headline'
```

Reload: `prefix + I` (TPM) or `tmux source ~/.tmux.conf`.

### 2. Agent hooks

```bash
claude plugin install tmux-headline
```

Plugin contents:
- `commands/headline.md` — the `/headline` slash command
- `skills/headline-naming/SKILL.md` — instructions for when to call `/headline`
- `hooks/{stop-sync,session-end}.sh` — usage poll + cleanup (unrelated to headline)

**Pi:** `cp extensions/tmux-status.ts ~/.pi/agent/extensions/`

**Codex:** works out of the box. Codex writes `pane_title` natively.

## What this plugin sets in tmux

Conservatively, only **two** globals — each gated on user defaults:

| Option | Set when | Why |
|--------|----------|-----|
| `pane-border-status` | currently `off` (tmux default) | needed to display the title above each pane |
| `pane-border-format` | currently the tmux default | renders `#{pane_title}` with index + cwd |

Plus `allow-rename on` so any agent can write `pane_title` via OSC.

If you have your own `pane-border-format`, the plugin **doesn't touch it**. Manual opt-in:

```tmux
set -g pane-border-status top
set -g pane-border-format "#{pane_index} #[fg=colour90]#{pane_title}#[default] #[fg=cyan]#{session_name}#[default] #[dim]#{b:pane_current_path}#[default]"
```

For window tabs (opt-in):

```tmux
set -g window-status-format         " #I #[fg=colour244]#{=24:pane_title}#[default] "
set -g window-status-current-format "#[fg=colour15,bg=colour239,bold] #I #{pane_title} #[default]"
```

## Files

```
commands/headline.md             /headline slash command (validates 2-4 words, sets pane_title)
skills/headline-naming/SKILL.md  triggers Claude to call /headline on workstream shifts
hooks/hooks.json                 declares Stop + SessionEnd hooks (no UserPromptSubmit)
hooks/stop-sync.sh               background usage poll
hooks/session-end.sh             cleanup residual files
scripts/extract-headline.sh      transcript-mode extraction (used by Pi)
scripts/spinner.sh               1fps braille frame utility
scripts/usage-poll.sh            subscription usage poller
extensions/tmux-status.ts        Pi extension (independent codepath)
statusline.js                    rich statusline for Claude/Codex
headline.tmux                    TPM entrypoint — minimal, default-gated globals
```

## Storage

```
~/.local/share/tmux-headline/
  data/usage.json              # subscription usage cache (60s throttled)
```

The Claude side no longer stores headline files — `pane_title` is the live source of truth, set by `/headline` directly. Pi continues to use `headlines/<sid>.headline` for its own purposes.

## Uninstall

```bash
claude plugin uninstall tmux-headline
rm -rf ~/.local/share/tmux-headline
```

If you added the TPM line manually, remove it from `~/.tmux.conf` and reload.
