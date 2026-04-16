# tmux-headline (Codex)

After completing your response, set a headline in the pane title using the new data directory.

```bash
printf '\033]2;⠿ HEADLINE\007'
```

Replace `HEADLINE` with a 1-3 word summary of what you just worked on (e.g. `fix auth` or `refactor plugin`).

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
