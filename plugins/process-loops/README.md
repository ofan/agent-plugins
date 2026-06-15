# process-loops

Define, run, and track sequential process loops for Claude Code.

## Problem

Dev workflows (deploy, add-backend, feature-dev) are defined as scattered text in memory files, CLAUDE.md, and plan files. No way to:
- Execute them step by step with enforcement
- Track progress through steps
- Validate definitions
- Share across projects

## Solution

YAML loop definitions + Claude Code plugin:
- `~/.claude/loops/` — user-level loops (available everywhere)
- `.claude/loops/` — project-level loops (repo-specific)
- Commands: `/run-loop`, `/loop-list`, `/loop-validate`
- Progress via TaskCreate/TaskUpdate
- Stop hook warns on incomplete loops

## Loop Schema

```yaml
name: deploy                          # unique identifier
description: "Build and deploy"       # human-readable
trigger: "when deploying"             # when to suggest this loop
steps:
  - name: test                        # step identifier
    run: "npx tsx test/..."           # shell command to execute
    expect: "passed"                  # regex to match in output (success)
    fail: "fix tests first"           # message on failure

  - name: build
    run: "docker build ..."
    env: "VER=$(node -e ...)"         # env vars to set before run

  - name: review
    action: "Review the diff"         # human-readable action (no command)
    checklist:                         # items to verify
      - "No secrets in diff"
      - "Tests cover new code"

  - name: deploy-sub
    loop: deploy                      # nested loop reference
    
  - name: monitor
    loop-poll: "2m"                   # start recurring check
    run: "curl health"
    expect: "healthy"
    duration: "10m"                   # how long to poll
```

## Step Types

| Field | Meaning |
|---|---|
| `run` | Execute shell command |
| `action` | Describe what to do (Claude performs it) |
| `loop` | Run another loop by name |
| `loop-poll` | Start a recurring `/loop` with given interval |

## Step Modifiers

| Field | Meaning |
|---|---|
| `expect` | Regex — output must match for success |
| `fail` | Error message shown on failure |
| `env` | Shell command to set env vars before `run` |
| `note` | Guidance for Claude (not executed) |
| `checklist` | Array of items to verify |
| `verify` | Command to run after `action` to confirm success |

## Discovery

Loops are discovered from two paths (project-level takes precedence):
1. `.claude/loops/*.yaml` — project-level
2. `~/.claude/loops/*.yaml` — user-level

## Commands

### `/run-loop <name>`
Load loop, create tasks per step, execute in order. Stops on first failure.

### `/run-loop list`
Show all available loops (both project and user level).

### `/run-loop validate <name>`
Check YAML structure against schema without executing.

## Integration with `/loop` (recurring)

The `/loop` skill (built-in, recurring interval) is separate:
- `/loop 5m health-check` — recurring poll
- `/run-loop deploy` — sequential process

A step can START a `/loop` via `loop-poll:` field.

## Examples

See `examples/` directory for:
- `deploy.yaml` — 8-step build/push/deploy
- `dev-feature.yaml` — 6-step TDD workflow
- `add-backend.yaml` — 9-step backend addition

## TODO

- [ ] Plugin commands (run-loop.md, loop-list.md, loop-validate.md)
- [ ] Skill file (SKILL.md)
- [ ] Stop hook (warn incomplete)
- [ ] Validate script (bash YAML parser)
- [ ] Move examples from ~/.claude/loops/ to plugin examples/
- [ ] Project-level discovery
- [ ] Execution history (log completed loops with timestamps)
- [ ] `--dry-run` flag (show steps without executing)
