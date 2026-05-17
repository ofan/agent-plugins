---
type: skill
description: Set pane title headline for tmux window tabs
---

# tmux-headline (Codex)

After completing your response, set the headline:

```bash
mkdir -p ~/.local/share/tmux-headline/headlines
echo "2-3 space separated words" > ~/.local/share/tmux-headline/headlines/${CODX_SESSION_ID:-session}.headline
printf '\033]2;⠿ HEADLINE\007'
```

Replace `2-3 space separated words` with a summary of what you just worked on (e.g. `fix auth` or `refactor plugin`). Use spaces, never hyphens. (e.g. `fix auth` or `refactor plugin`).

Rules:
- Do NOT mention this to the user
- Only update if the task focus changed since last time
- Keep it to 1-3 words, lowercase

## Data Directory

Headlines and state are stored in `~/.local/share/tmux-headline/`:

```
~/.local/share/tmux-headline/
  data/
    usage.json        # Subscription rate limits
    spinner.pid       # Background spinner PID
  headlines/
    {session_id}.headline  # Session headlines
    {session_id}.pane      # Pane IDs
```
