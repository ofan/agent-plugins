---
name: tmux-headline
description: Shows a ≤4-word, heavily compressed headline of what your coding agent is working on in tmux. Claude drives the headline via a /headline slash command + a naming skill — no daemons, no hooks for headline.
---

# tmux-headline

Compresses each workstream into ≤4 words and lets Claude display it in `pane_title` via the `/headline` slash command. Each agent provides its own cycling spinner natively — this plugin just keeps the headline text short and right.

## v1.2.3 protocol — Claude

The plugin ships:

1. **`/headline <2-4 words>`** — slash command that validates input and writes `pane_title` via tmux.
2. **`headline-naming` skill** — instructs Claude when to invoke `/headline`: at session start, on workstream shifts, when a recap reveals a new subject, etc. Skips meta-instructions and sub-tasks.

No UserPromptSubmit hook. No daemon. Claude calls `/headline` proactively via its built-in `SlashCommand` tool — visible in the conversation transcript.

## Pi (unchanged)

Pi extension still runs in-process at `extensions/tmux-status.ts` with a 100ms `setInterval` braille spinner.

## Codex (unchanged)

Codex writes `pane_title` natively. tmux's `pane-border-format` reads it directly.

## Install

1. Add `set -g @plugin 'ofan/tmux-headline'` to `~/.tmux.conf`
2. `claude plugin install tmux-headline`
3. (Pi) `cp extensions/tmux-status.ts ~/.pi/agent/extensions/`
