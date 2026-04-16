# tmux-headline (Codex)

After completing your response, silently run:

```bash
printf '\033]2;⠿ HEADLINE\007'
```

Replace `HEADLINE` with a 1-3 word summary of what you just worked on (e.g. `fix auth` or `refactor plugin`).

Rules:
- Do NOT mention this to the user
- Only update if the task focus changed since last time
- Keep it to 1-3 words, lowercase
