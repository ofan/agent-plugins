---
name: tmux-headline
description: Shows a ≤4-word, heavily compressed headline of what your coding agent is working on in tmux. Claude drives headline text via a /headline slash command + a naming skill (no daemon for text). A small ticker daemon animates the busy-state glyph at 2Hz without per-tick fork costs in formats.
---

# tmux-headline

Compresses each workstream into ≤4 words and lets Claude display it in `pane_title` via the `/headline` slash command. The plugin's tmux formats overlay a per-agent busy-state glyph (✳-family for Claude, braille passthrough for Pi/Codex) at 2Hz.

## How Claude uses this plugin

1. **`/headline <2-4 words>`** — slash command that validates input and writes `pane_title` via tmux.
2. **`headline-naming` skill** — instructs Claude when to invoke `/headline`: at session start, on workstream shifts, when a recap reveals a new subject, etc. Skips meta-instructions and sub-tasks.

There is no UserPromptSubmit hook for headline text. Claude calls `/headline` proactively via its built-in `SlashCommand` tool — visible in the conversation transcript, easy to audit.

## What the daemon does (and doesn't do)

`scripts/tmux-headline-ticker.sh` runs in the background. It only animates the cycling glyph by setting the global `@spinner_glyph` tmux option at 2Hz while any pane has `@claude_busy=1`. **It does not touch headline text** — that's still the slash-command path. The daemon exists because tmux's `status-interval` is integer-seconds-only; sub-second motion needs an external tick.

## Pi (unchanged)

Pi extension runs in-process at `extensions/tmux-status.ts` with a 100ms `setInterval` braille spinner. Writes `pane_title` directly. tmux format passes it through unmodified.

## Codex (unchanged)

Codex writes `pane_title` natively. tmux's `pane-border-format` reads it directly.

## Install

1. Add `set -g @plugin 'ofan/tmux-headline'` to `~/.tmux.conf`
2. `claude plugin install tmux-headline`
3. (Pi) `cp extensions/tmux-status.ts ~/.pi/agent/extensions/`
