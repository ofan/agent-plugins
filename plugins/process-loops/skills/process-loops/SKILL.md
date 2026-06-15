---
description: "Manage and execute sequential process loops for development workflows (deploy, feature dev, backend addition). Use when the user mentions 'loop', 'workflow', 'process', 'deploy steps', 'dev loop', or asks to run a defined sequence of steps."
---

# Process Loops

Sequential development workflows defined as YAML, executed step by step with progress tracking.

## Available Commands

- `/run-loop <name>` — Execute a loop (e.g., `/run-loop deploy`)
- `/run-loop list` — Show all available loops
- `/run-loop validate <name>` — Check loop YAML is valid

## Loop Locations

- Project-level: `.claude/loops/*.yaml` (current repo)
- User-level: `~/.claude/loops/*.yaml` (global)

## When To Suggest

Suggest running a loop when the user is about to:
- Deploy code → `/run-loop deploy`
- Start a new feature → `/run-loop dev-feature`
- Add a backend → `/run-loop add-backend`

## Creating New Loops

Loops are YAML files with this structure:

```yaml
name: my-loop
description: "What this loop does"
trigger: "when to run this"
steps:
  - name: step-name
    run: "command"        # shell command
    expect: "pattern"    # success regex
    fail: "error msg"    # failure message
  - name: manual-step
    action: "Do this"    # Claude performs the action
    verify: "command"    # verification after action
```

Save to `.claude/loops/my-loop.yaml` (project) or `~/.claude/loops/my-loop.yaml` (global).
