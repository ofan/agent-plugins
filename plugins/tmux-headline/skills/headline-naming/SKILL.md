---
name: headline-naming
description: Use during coding sessions in tmux to keep the pane headline aligned with the current workstream. Trigger when a session begins, when the conversation's subject genuinely shifts, or when a recap reveals a different workstream than the current pane label.
---

# Naming the tmux pane workstream

Whenever the conversation moves to a new goal or subject — at session start, on topic shifts, or when a recap shows the workstream has drifted — invoke:

```
/headline <2 to 4 lowercase words>
```

This sets the visible tmux pane title to a short workstream label.

## Rules for the label

- **2 to 4 lowercase words**, no punctuation
- Name the **goal or subject**, not the user's specific question
- Ignore meta-instructions ("tldr", "fix it", "explain", "show me", "thanks")
- Skip on sub-tasks within the current workstream — only call when the *subject* changes

## Examples

| User context | Call |
|---|---|
| New session about home infra | `/headline homeinfra improvement` |
| Switching to deploy auth service | `/headline auth service deploy` |
| Working on the same thing → user asks "tldr" | (skip — meta-instruction) |
| Working on the same thing → user asks "fix that bug" | (skip — sub-task within current workstream) |
| Conversation pivots from auth to billing | `/headline billing migration` |

## Recap integration

Claude Code may surface a recap line that begins with `※ recap:` and includes both the current state and the next step. Treat the **subject** of the recap as the canonical workstream. If your current pane headline doesn't match it, run `/headline` to sync.

Example:
> ※ recap: Building memex into a cross-device memory system; daemon and Claude Code plugin are deployed and the v0.6 work is on a feature branch with main protected. Next: draft the setup script…

→ `/headline memex memory system`

## When not to call

- The user's prompt is a follow-up, clarification, ack, or short meta-command
- The current pane headline already matches the workstream (don't churn)
- You can't be confident in 2-4 words yet — wait for more context
