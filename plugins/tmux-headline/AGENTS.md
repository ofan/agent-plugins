# tmux-headline Agent Notes

## Source Of Truth
- This directory is the source of truth for the `tmux-headline` plugin.
- Make code and doc changes here first.
- Do not treat `~/.agents/skills/tmux-headline` or other installed copies as canonical.

## Update Flow
- Develop and test changes in this plugin directory.
- Commit and push changes from the `agent-plugins` repo.
- Publish a plugin release from the source repo.
- After release, update or reinstall the plugin in Claude/Codex environments.

## Scope
- `README.md`, `SKILL.md`, `statusline.js`, `hooks/`, and `scripts/` should stay consistent.
- Keep Claude hook-based behavior documented separately from Codex `terminal_title` / `pane_title` behavior.

## Local Config
- User-specific tmux configuration lives outside this plugin, typically in `~/.tmux.conf`.
- Do not move personal tmux settings into the plugin unless the change is intended to ship to all users.
