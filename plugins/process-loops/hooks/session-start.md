---
event: SessionStart
description: "Discover and inject available process loops into session context"
---

# Discover Process Loops

On session start, discover available loops and inject them into context.

## Discovery

Check both paths for `.yaml` files:
1. `.claude/loops/` in the current working directory (project-level)
2. `~/.claude/loops/` (user-level)

## Output

If loops are found, output a brief summary:

```
Available process loops (use /run-loop <name> to execute):
• deploy — Build, push, and deploy a new version (8 steps)
• dev-feature — TDD workflow for implementing a feature (6 steps)
• add-backend — Add a new LLM backend (9 steps)
```

Show at most 10 loops. If more exist, add: "Use /run-loop list for all N loops."

## How to detect loops

Read each YAML file and extract `name:` and `description:` from the first few lines. Count steps by counting `- name:` occurrences.

Do NOT read full file contents — just the header fields for the summary.
