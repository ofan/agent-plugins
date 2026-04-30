# tmux-headline

Compresses each workstream into a ≤4-word headline displayed in tmux pane borders and window tabs, with a per-agent busy-state glyph. Works with **Claude Code**, **Codex**, and **Pi**.

```
 1 ✻ review next component   2 ✷ fix tmux freeze   3 ✦ load context check
                              ↑
                        2Hz cycling glyph while @claude_busy=1
```

---

## How it works

Two mostly-independent layers. The **headline text** is set by each agent on demand; the **glyph** is animated by tmux formats reading per-pane state.

### Layer 1 — headline text (per-agent, on demand)

```
Claude observes a workstream shift (or session start, or recap)
                  │
                  ▼
   skill: headline-naming triggers Claude to call /headline
                  │
                  ▼
       /headline auth service deploy   ← visible tool call
                  │
                  ▼
   command body runs:  tmux select-pane -T "auth service deploy"
                  │
                  ▼
   pane_title becomes "auth service deploy"
                  │
                  ▼
   tmux re-renders pane border + window tabs
```

No daemon and no hook are involved in setting headline text. The slash call shows up in the transcript so it's auditable.

| Agent | Headline source |
|-------|-----------------|
| Claude | `/headline` slash command (this plugin) + `headline-naming` skill |
| Pi | in-process `setInterval` writes `pane_title` directly (`extensions/tmux-status.ts`) |
| Codex | Codex itself writes `pane_title` |

### Layer 2 — busy glyph (tmux format + ticker daemon)

The plugin overlays a small colored glyph in front of the headline text to signal busy/idle:

| @claude_busy | Visual | Source |
|---|---|---|
| `1` (turn in progress) | bright yellow `✳ ✶ ✷ ✺ ✸ ✦` cycling at 2Hz | `tmux-headline-ticker.sh` daemon writes `@spinner_glyph` |
| `0` (idle) | dim grey `✻` | literal in the format, no fork |
| unset (Pi/Codex pane) | original `pane_title` passes through | format falls to `else` branch |

The hooks (`UserPromptSubmit` → 1, `Stop` → 0) flip `@claude_busy` per pane.

#### Why a ticker daemon?

tmux's `status-interval` is integer-seconds (1, 2, 3 — not `0.5`). `#(shell-cmd)` invocations in formats only re-run at status-interval ticks. If you want sub-second spinner motion, *something* outside tmux has to drive it.

The ticker is that something:

```
tmux-headline-ticker.sh (background loop, ≤1 instance per server)
        │ every 0.5s while any pane has @claude_busy=1
        ▼
tmux set -g @spinner_glyph "<next frame>" \; refresh-client -S
        │
        ▼
formats read #{@spinner_glyph} (zero forks per evaluation) → tabs redraw
```

When all panes are idle, the ticker drops to 1Hz busy-state polling. Cycle stops, no redraws happen.

#### Why this design — the fork-storm story

Earlier versions (`1.2.x`) placed `#(headline-render.sh #{pane_id} glyph)` and `#(... text)` inside `window-status-format`, `window-status-current-format`, *and* `pane-border-format`. With `status-interval=1` and several panes, this fanned out to ~10 short shells per second, each spawning further `tmux display-message` IPCs. On busy systems with SSH attached, the per-tick burst stalled the tmux server's keystroke loop for 100–300ms — visible as ~1Hz "freezes" while typing.

`1.4.0` replaces all `#()` in formats with **pure tmux format expressions** (`#{?...,...,...}`, `#{m:pattern,target}`, `#{s/regex/replacement/format}`). The animated glyph still needs a tick, but it comes from a single background daemon instead of N×M shell forks per status update.

Measured impact on a typical box:

| State | Forks/sec | PSI cpu avg10 | Notes |
|---|---|---|---|
| `1.2.x` (fork storm) | ~127 | ~2.4 | Caused SSH stutters |
| `1.4.0` idle | ~28 | ~0.30 | Baseline (other system noise) |
| `1.4.0` Claude busy + ticker | ~44 | ~0.43 | +16 forks/sec, +0.13 PSI |

---

## Install

### 1. tmux (TPM)

```tmux
set -g @plugin 'ofan/tmux-headline'
```

Reload: `prefix + I` (TPM) or `tmux source ~/.tmux.conf`.

Or run `./install.sh` from the plugin directory — it handles tmux config, agent hook sync, Pi extension copy, and Codex instructions.

### 2. Agent hooks

```bash
claude plugin install tmux-headline
```

Plugin contents shipped to Claude Code:
- `commands/headline.md` — the `/headline` slash command
- `skills/headline-naming/SKILL.md` — instructions for when to call `/headline`
- `hooks/headline-busy.sh` — `UserPromptSubmit` hook, sets `@claude_busy=1`
- `hooks/stop-sync.sh` — `Stop` hook, sets `@claude_busy=0` + usage poll
- `hooks/session-end.sh` — `SessionEnd` cleanup

**Pi:** `cp extensions/tmux-status.ts ~/.pi/agent/extensions/`

**Codex:** works out of the box. Codex writes `pane_title` natively.

---

## What this plugin sets in tmux

| Option | When set | Why |
|--------|----------|-----|
| `status-interval` | always (forced to `1`) | Status bar redraws every second so glyph updates are visible |
| `pane-border-status` | currently `off` | Display the title above each pane |
| `pane-border-format` | matches tmux default *or* a previous version of this plugin | Shows headline in the pane border |
| `window-status-format` | matches tmux default *or* a previous version of this plugin | Shows headline in inactive window tabs |
| `window-status-current-format` | same gate as above | Shows headline in the active tab |
| `allow-rename on` | always | Lets agents write `pane_title` via OSC |
| `@spinner_glyph` | by the ticker daemon, every 500ms while busy | Source of the cycling glyph for formats to read |

### Format detection (legacy & upgrade)

`headline.tmux` uses two markers to recognize "previous version of this plugin's own format" and replace it on upgrade — avoiding the trap where the first install's settings stick around forever:

1. Substring `headline-render.sh` → `1.2.x` and earlier (`#()` shell calls).
2. Substring `[⠁-⣿✻✳✶✷✺✸✦⠿]` → `1.3.0+` (the unique glyph class in `HAS_GLYPH`).

If your `pane-border-format` (etc.) contains neither — i.e. it's truly user-customized — the plugin **doesn't touch it**.

---

## Architecture diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│ ~/.tmux.conf                                                         │
│   set -g @plugin 'ofan/tmux-headline'                                │
└──────────────┬───────────────────────────────────────────────────────┘
               │ run-shell
               ▼
┌──────────────────────────────────────────────────────────────────────┐
│ headline.tmux (entry script)                                         │
│   1. set status-interval 1                                           │
│   2. set window-status-format / window-status-current-format /       │
│      pane-border-format    (gated: default or legacy only)           │
│   3. pkill any running ticker, nohup-spawn fresh one                 │
└──────────────┬───────────────────────────┬───────────────────────────┘
               │ formats reference         │ spawns
               ▼                           ▼
┌─────────────────────────────────┐  ┌────────────────────────────────┐
│ tmux format engine              │  │ scripts/tmux-headline-ticker.sh│
│   #{?@claude_busy,              │  │ while tmux info >/dev/null; do │
│     #{?@spinner_glyph,          │  │   busy=$(tmux list-panes …)    │
│       #{@spinner_glyph}, ✳},    │  │   if any pane busy:            │
│     ✻}                          │  │     tmux set -g @spinner_glyph │
│   #{s/^[^ ][^ ]* //:pane_title} │◀─┤              \;refresh-client  │
│   evaluated per redraw          │  │     sleep 0.5                  │
└─────────────────────────────────┘  │   else: sleep 1                │
                                     │ done                           │
                                     └────────────────────────────────┘
                                              ▲
                                              │ reads @claude_busy set by:
                                              │
┌─────────────────────────────────────────────┴────────────────────────┐
│ Claude Code hooks (cache install)                                    │
│   UserPromptSubmit → headline-busy.sh  → tmux set -p @claude_busy 1  │
│   Stop             → stop-sync.sh      → tmux set -p @claude_busy 0  │
│   SessionEnd       → session-end.sh    → cleanup                     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Files

```
.claude-plugin/plugin.json        plugin manifest, version field
headline.tmux                     TPM entrypoint — sets formats, starts ticker
install.sh                        tmux + Claude + Pi + Codex installer

commands/headline.md              /headline slash command (validates 2-4 words)
skills/headline-naming/SKILL.md   triggers Claude to call /headline

hooks/hooks.json                  declares UserPromptSubmit + Stop + SessionEnd
hooks/headline-busy.sh            UserPromptSubmit: set @claude_busy=1
hooks/stop-sync.sh                Stop: set @claude_busy=0 + usage poll
hooks/session-end.sh              SessionEnd: cleanup

scripts/tmux-headline-ticker.sh   background daemon driving @spinner_glyph at 2Hz
scripts/claude-spinner.sh         single-frame emitter (used by /headline command)
scripts/extract-headline.sh       transcript-mode extraction (Pi)
scripts/spinner.sh                braille frame utility (general purpose)
scripts/usage-poll.sh             subscription usage poller
scripts/git-status.sh             tmux status helper
scripts/headline-render.sh        legacy single-pane renderer (kept for compatibility)

extensions/tmux-status.ts         Pi extension (independent codepath)
statusline.js                     rich Claude/Codex statusline
```

---

## Storage & runtime files

```
~/.local/share/tmux-headline/
  data/usage.json                       # subscription usage cache (60s throttled)
  headlines/<session-id>.last_good      # Pi's per-session last good headline

/tmp/tmux-headline-ticker.${USER}.pid   # ticker daemon PID, removed on exit via trap
```

The Claude side doesn't store headline files — `pane_title` is the live source of truth, set by `/headline`. The ticker writes only the global `@spinner_glyph` tmux option (no files).

---

## Per-agent glyph identity

This is a hard convention; don't cross-pollinate when editing:

- **Claude**: ✳-family (`✳ ✶ ✷ ✺ ✸ ✦`). Driven by `claude-spinner.sh` / `tmux-headline-ticker.sh`.
- **Pi**: braille range `⠁-⣿`. Pi writes the cycling frame directly into `pane_title`; format passes through.
- **Codex**: whatever Codex sets in `pane_title`; format passes through.
- **Idle / fallback prefix for non-Claude panes**: `⠿`.

The format detects "first character of `pane_title` is in `[⠁-⣿✻✳✶✷✺✸✦⠿]`" and decides whether to overlay the Claude-styled glyph or pass through.

---

## Performance budget

The plugin is designed not to be the source of any visible system load:

| Cost item | Where | Rate |
|---|---|---|
| Format evaluation per status sweep | tmux internal | 0 forks (pure expression) |
| Busy poll | ticker daemon | 1 fork/sec |
| Spinner advance + redraw | ticker daemon | 2 forks/sec while busy |
| `tmux refresh-client -S` | ticker daemon | bundled into the advance call |
| Hook firing | Claude Code lifecycle | once per turn boundary |

Total steady-state overhead: ~2 forks/sec idle, ~4–6 forks/sec while a Claude turn is in progress. Verified to keep PSI cpu pressure under 0.5 on the avg10 window.

---

## Uninstall

```bash
claude plugin uninstall tmux-headline
rm -rf ~/.local/share/tmux-headline
kill "$(cat /tmp/tmux-headline-ticker.${USER}.pid 2>/dev/null)" 2>/dev/null
```

If you added the TPM line manually, remove it from `~/.tmux.conf` and reload.

---

## Changelog

### 1.4.0 — fork-free formats + ticker daemon

- **Fixed**: SSH stutters caused by `#(headline-render.sh ...)` per-pane fan-out at `status-interval=1`. Formats are now pure tmux expression — zero forks per status sweep.
- **Added**: `scripts/tmux-headline-ticker.sh` — single background daemon advances `@spinner_glyph` at 2Hz only while any pane has `@claude_busy=1`.
- **Added**: legacy format detection — re-running `headline.tmux` after upgrade reliably swaps in the new format strings, even if a previous version's strings are stuck in the running server.
- **Added**: `install.sh` syncs to *every* Claude install location (`mapfile` over `find` matches), not just the first one.
- **Changed**: spinner is now plugin-driven via the ticker, not pulled from Claude's pane_title leading char.

### 1.3.0 — `/headline` command + skill

- Replaced UserPromptSubmit-driven headline auto-naming with `/headline` slash command + `headline-naming` skill.
- No daemon for headline text (still true; the ticker only drives the glyph).
