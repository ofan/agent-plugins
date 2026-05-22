---
name: headline-naming
description: Auto-call /rename when the workstream changes. Session start, topic shifts, after recaps. Use judgment for scope.
---

# Track the workstream

When the workstream genuinely changes, run this bash to update the tmux headline:

```bash
mkdir -p ~/.local/share/tmux-headline/headlines && echo "<2-4 words>" > ~/.local/share/tmux-headline/headlines/$CLAUDE_SESSION_ID.headline && tmux set-option -p -t "$TMUX_PANE" @headline "<2-4 words>" && tmux select-pane -t "$TMUX_PANE" -T "<2-4 words>"
```

Replace `<2-4 words>` with a lowercase, space-separated label for the current workstream goal. No hyphens, no punctuation, no capitals.

This writes the headline file (so hooks can restore it on next prompt) and sets @headline + pane_title immediately for live display in the tmux tab.

## When to call

- **Session start** — always. Name the initial goal.
- **Topic shift** — the conversation moves to a different feature, bug, or system.
- **After recap** — the recap shows a different subject than the current name.

## When NOT to call

- **Small detour** — user asks a quick sub-question within the same workstream
- **Follow-ups** — "what about X?", "also fix Y" within same scope
- **Meta** — "tldr", "thanks", "explain this", "what's that file?"
- **Same scope** — the current name already matches

## Judgment

If the workstream shift is a genuine new task/feature that will take multiple turns, rename. If it's a single-question detour then back to the main workstream, don't.

## Examples

| Context | Call? |
|---|---|
| Start of session: "fix the auth middleware" | `fix auth middleware` |
| Mid-session: "now let's add rate limiting" | `add rate limiting` |
| Same scope: "also update the tests for that" | skip |
| Detour: "btw what port does nginx use?" | skip (single question) |
| Pivot: "ok let's switch to the billing bug" | `billing bug` |

**Important**: Always use lowercase, spaces between words. No hyphens, no punctuation.
