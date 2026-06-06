---
name: do-release
description: Release a new version of a plugin. Analyze changes, decide version bump, commit and push.
---

# Release a plugin

Check the working tree changes and decide the version bump.

## Decision rules

| Change type | Examples | Version bump |
|---|---|---|
| **major** | format rewrite, new components (skills/agents/hooks/commands), architecture change, data-flow redesign | minor (1.5.0 → 1.6.0) |
| **patch** | bug fix, prompt tweak, small logic change, config adjustment, display polish | patch (1.5.0 → 1.5.1) |

## Steps

1. Run `git diff --stat` and `git status` to see what changed
2. Read the diff to understand the nature of each change
3. Decide: major or patch
4. Bump the version in `.claude-plugin/plugin.json`
5. Commit all changes with a `plugin-name: summary` message
6. Push
7. Run `claude plugin marketplace update ofan-plugins` to sync cache

Only bump the minor version when there's a meaningful shift in how the plugin works — new capabilities, new files, or rearchitected logic. Simple fixes, cleanup, and cosmetic changes get a patch bump.
