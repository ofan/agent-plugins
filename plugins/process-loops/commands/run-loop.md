---
description: "Run a defined process loop — execute steps sequentially with progress tracking"
argument-hint: "<loop-name> or 'list' to see available loops"
---

# Run Loop

Execute a process loop defined in YAML.

## Discovery

Read loop definitions from (project-level first, then user-level):
1. `.claude/loops/*.yaml` in the current working directory
2. `~/.claude/loops/*.yaml` for user-level loops

## Execution

If argument is "list" — show all available loops with name + description.

If argument is "validate <name>" — parse the YAML and check required fields exist. Report errors.

Otherwise, load `<argument>.yaml` from the discovery paths and execute:

1. Parse the YAML file (simple key-value structure)
2. Create a TaskCreate item for each step (subject = step name, description = step details)
3. Execute steps in order:

For each step:
- Set task to `in_progress`
- If `env:` — evaluate and export variables (e.g., `VER=$(node -e ...)`)
- If `run:` — execute the shell command
  - If `expect:` — check output matches regex. If not, show `fail:` message and STOP.
- If `action:` — perform the described work
  - If `verify:` — run verification command after
  - If `checklist:` — confirm each item is addressed
- If `loop:` — recursively invoke that loop
- Mark task as `completed`
- Move to next step

4. On failure: stop, report which step failed and why. Don't continue.
5. On success: report loop name, steps completed, total duration.

## Variable Expansion

`$VER` expands to the current package.json version throughout all commands.
`${CLAUDE_PLUGIN_ROOT}` expands to the plugin directory.

## Rules

- NEVER skip steps
- STOP on first failure
- Mark tasks as you go (in_progress → completed)
- For `run:` steps — execute the actual command and check output
- For `action:` steps — perform the work described, then verify if applicable
