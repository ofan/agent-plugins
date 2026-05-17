---
name: headline-naming
description: Auto-call /rename when the workstream changes. Session start, topic shifts, after recaps. Use judgment for scope.
---

# Track the workstream

**Call `/rename <2-4 words>`** (space-separated, no hyphens) when the workstream genuinely changes. This sets the session name, which syncs to the tmux tab via the plugin.

## When to call

- **Session start** — always. Name the initial goal.
- **Topic shift** — the conversation moves to a different feature, bug, or system. Call it.
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
| Start of session: "fix the auth middleware" | `/rename auth middleware` |
| Mid-session: "now let's add rate limiting" | `/rename rate limiting` |
| Same scope: "also update the tests for that" | skip |
| Detour: "btw what port does nginx use?" | skip (single question) |
| Pivot: "ok let's switch to the billing bug" | `/rename billing bug` |

**Important**: Always use spaces between words, never hyphens. `/rename auth middleware` not `/rename auth-middleware`.
