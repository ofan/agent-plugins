# tmux-headline

Claude Code plugin that shows session headlines, animated spinner, and subscription usage in your tmux status bar and Claude statusline.

Instead of every window showing `claude`, you see what each session is actually working on:

```
 0 ✳ openclaw dashboard   1 ✶ memclaw dev   2 · disclaw session
```

- Busy sessions show an animated spinner (cycles every second)
- Idle sessions show `✳`
- Non-Claude windows are unaffected

## Install

```sh
# Via marketplace
claude plugin marketplace add ofan/claude-plugins
claude plugin install tmux-headline@ofan-plugins
```

## tmux config

Add these to your `~/.tmux.conf`:

```tmux
# Dark status bar
set -g status-style "bg=colour237,fg=colour248"
set -g status-interval 1

# Window tabs — Claude windows show spinner + headline, others show name
set -g window-status-format " #I #{?#{@headline},#{?#{m:✳*,#{pane_title}},#[fg=colour244]✳,#[fg=yellow]#(~/.claude/plugins/local/tmux-headline/scripts/spinner.sh)#[default]}#[fg=colour244] #{=18:@headline}#[default],#W} "
set -g window-status-current-format "#[fg=colour15,bg=colour239,bold] #I #{?#{@headline},#{?#{m:✳*,#{pane_title}},✳,#[fg=yellow]#(~/.claude/plugins/local/tmux-headline/scripts/spinner.sh)#[fg=colour15]} #{=18:@headline},#W} #[default]"
set -g window-status-separator " "

# Pane border with headline
set -g pane-border-status top
set -g pane-border-format "#{pane_index} #{?#{@pane_headline},#[fg=colour90]#{@pane_headline}#[default] ,}#[fg=cyan]#{session_name}#[default] #{pane_title} #[dim]#{b:pane_current_path}#[default]"
```

Replace the spinner.sh path with your actual plugin path if different.

## How it works

Four hooks working together:

| Hook | What it does |
|------|-------------|
| **SessionStart** | Registers session ID -> tmux pane/window mapping in `state.json` |
| **UserPromptSubmit** | Injects a system reminder asking Claude to write a short headline |
| **Stop** | Syncs headlines to tmux options; re-appends `custom-title` to `.jsonl`; polls subscription usage in background |
| **SessionEnd** | Cleans up state and headline files |

Runtime state lives in `~/.claude/headline/`:
- `state.json` -- session -> tmux pane mapping
- `headlines/<session-id>.headline` -- plain text headline per session
- `usage.json` -- cached subscription usage (5h/7d limits + reset times)

## Spinner styles

Set `HEADLINE_SPINNER` env var to switch:

| Style | Frames | Description |
|-------|--------|-------------|
| `flowers` (default) | `· ✢ ✽ ✶ ✽ ✢` | Star glyphs, small -> big -> small |
| `claude` | `⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏` | Claude's actual braille spinner |
| `braille` | 16 frames | Clockwise fill and drain |
| `dots` | `· • ● • ·` | Pulsing dot |

```sh
export HEADLINE_SPINNER=claude
```

## Subscription usage polling

Shows your 5-hour and 7-day usage limits in Claude's statusline:

```
14%⏳2h10 · 44%⏳Thu 23:00
```

- First number: 5-hour rolling window usage with relative reset time
- Second number: 7-day weekly quota usage with reset day + local time
- Color-coded: green -> yellow -> red as usage increases

### How it works

Sends a minimal Haiku API call (~9 tokens) with the `oauth-2025-04-20` beta header to read `anthropic-ratelimit-unified-*` response headers. Results cached to `~/.claude/headline/usage.json`, polled at most once per 60 seconds via the Stop hook.

### Credential sources

The poll script reads OAuth tokens from (in order):

1. **`~/.claude/.credentials.json`** — file-based credentials (Linux, older Claude Code versions)
2. **macOS Keychain** — `Claude Code-credentials` service entry (current Claude Code on macOS)

If neither source has a valid, non-expired token, the poll is silently skipped.

### Statusline setup

Copy `statusline.js` to `~/.claude/` and add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "node \"$HOME/.claude/statusline.js\""
  }
}
```

The statusline also shows git status (branch, staged, modified, untracked, ahead/behind, worktree detection) and context window usage.

## Session naming

The plugin automatically names your Claude sessions with the headline text. When you `/resume`, you'll see descriptive names like "tmux headline plugin" instead of random slugs like "swirling-chasing-dewdrop".

This works by appending `{"type":"custom-title"}` entries to the session `.jsonl` file on every Stop hook -- keeping the title within Claude's 64KB tail scan window.

## Requirements

- tmux 3.1+ (for `#{m:pattern}` format matching)
- Claude Code 2.1.50+
- Python 3 (for JSON state management in hooks)

## License

MIT
