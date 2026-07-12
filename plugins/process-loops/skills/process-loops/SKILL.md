---
description: "Manage and execute sequential process loops for development workflows (deploy, feature dev, backend addition). Use when the user mentions 'loop', 'workflow', 'process', 'deploy steps', 'dev loop', or asks to run a defined sequence of steps. If no registered loop fits, fall back to the superpowers skills (brainstorming/writing-plans/executing-plans/test-driven-development/systematic-debugging) and offer to add a loop."
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

## Fallback (when no registered loop fits)

If the user mentions "loop"/"workflow" but **no loop in `.claude/loops/` or `~/.claude/loops/` matches**, don't force-fit — fall back to the matching **superpowers** skill:

- designing a feature / new behavior → `superpowers:brainstorming`
- approved spec → steps → `superpowers:writing-plans`
- implementing a plan → `superpowers:executing-plans` / `superpowers:test-driven-development`
- a bug / test failure / unexpected behavior → `superpowers:systematic-debugging`

Then fire the **add prompt** below (the task was loop-shaped but uncovered).

## Self-improve (add / improve loops — but don't nag)

- **Add prompt** — when you fall back to superpowers *or* run a one-off multi-step process the user will likely repeat, AND it was **≥3 steps + plausibly repeatable**, say:
  > *"That looked loop-shaped but no loop was registered. Want me to add a `<suggested-name>` loop? I'll write `.claude/loops/<name>.yaml` from the steps I just ran."*
  If yes → write the YAML (concrete `run:`/`action:` steps) to `.claude/loops/` (repo) or `~/.claude/loops/` (global).
- **Improve prompt** — after running a registered loop, if a step was missing/vague or you ad-libbed material work, say:
  > *"The `<name>` loop could be tightened — e.g. `<change>`. Want me to update its YAML?"*
  If yes → edit the loop YAML.

**Gating (avoid nagging):** at most **one self-improve prompt per turn**; **skip entirely inside `/goal`-driven top-level runs** (don't interrupt a driven flow); **suppress prompts from nested loops** (a `loop:` step runs silently). Never prompt if the work was trivially one-off.
