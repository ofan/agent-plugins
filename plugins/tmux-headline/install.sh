#!/usr/bin/env bash
# tmux-headline installer
# Detects available agents and sets up everything.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
OK=0 SKIP=0 ERR=0

ok()   { printf '  ✓ %s\n' "$1"; ((OK++)); }
skip() { printf '  · %s (skipped: %s)\n' "$1" "$2"; ((SKIP++)); }
err()  { printf '  ✗ %s (%s)\n' "$1" "$2"; ((ERR++)); }

printf 'tmux-headline installer\n\n'

# ── 1. tmux ───────────────────────────────────────────────────

printf '── tmux ──\n'

if ! command -v tmux &>/dev/null; then
  err "tmux" "not installed"
  printf '\nInstall tmux first.\n'
  exit 1
fi

# Check version (need 3.1+ for #{s//:} substitution)
TMUX_VER=$(tmux -V | grep -oE '[0-9]+\.[0-9]+')
if awk "BEGIN{exit !($TMUX_VER >= 3.1)}"; then
  ok "tmux $TMUX_VER"
else
  err "tmux $TMUX_VER" "need 3.1+"
  exit 1
fi

# Apply tmux formats. Works whenever a tmux server is running, not just when
# the installer itself is inside a tmux session — `tmux set -g` reaches the
# server via the socket. headline.tmux self-detects legacy fork-storm formats
# (`#(headline-render.sh ...)` substring) and resets them, so re-running after
# an upgrade is safe and idempotent.
if tmux info >/dev/null 2>&1; then
  bash "$PLUGIN_DIR/headline.tmux"
  ok "tmux formats applied to running server"
else
  skip "tmux formats" "no tmux server running — will apply on next start"
fi

# Add to tmux.conf if not already there
TMUX_CONF="${HOME}/.tmux.conf"
if [ -f "$TMUX_CONF" ] && grep -q 'headline\.tmux\|tmux-headline' "$TMUX_CONF" 2>/dev/null; then
  ok "tmux.conf already configured"
else
  printf '\n# tmux-headline: agent status in window tabs\nrun-shell %s/headline.tmux\n' "$PLUGIN_DIR" >> "$TMUX_CONF"
  ok "added run-shell to ~/.tmux.conf"
fi

# ── 2. Claude Code ────────────────────────────────────────────

printf '\n── Claude Code ──\n'

if command -v claude &>/dev/null; then
  # Sync to every installed location. Claude Code keeps two copies:
  #   - cache/ofan-plugins/tmux-headline/<version>/  (runtime — hooks read here)
  #   - marketplaces/ofan-plugins/plugins/tmux-headline/  (source clone)
  # The cache is the load-bearing one; the marketplace clone gets clobbered on
  # next refresh, but syncing both keeps a fresh install consistent.
  mapfile -t INSTALLED_HOOKS < <(find ~/.claude/plugins -path '*tmux-headline*/hooks.json' 2>/dev/null)
  if [ "${#INSTALLED_HOOKS[@]}" -gt 0 ]; then
    for hooks_json in "${INSTALLED_HOOKS[@]}"; do
      DEST=$(dirname "$(dirname "$hooks_json")")
      cp "$PLUGIN_DIR"/hooks/*.sh "$DEST/hooks/" 2>/dev/null
      cp "$PLUGIN_DIR"/headline.tmux "$DEST/" 2>/dev/null
      mkdir -p "$DEST/scripts"
      cp "$PLUGIN_DIR"/scripts/*.sh "$DEST/scripts/" 2>/dev/null
      chmod +x "$DEST/headline.tmux" "$DEST"/hooks/*.sh "$DEST"/scripts/*.sh 2>/dev/null
      ok "synced to ${DEST/#$HOME/~}"
    done
  else
    # Try installing via claude CLI
    if claude plugin install tmux-headline 2>/dev/null; then
      ok "claude plugin installed"
    else
      skip "claude plugin" "install manually: claude plugin install tmux-headline"
    fi
  fi
else
  skip "Claude Code" "not installed"
fi

# ── 3. Pi ─────────────────────────────────────────────────────

printf '\n── Pi ──\n'

PI_EXT_DIR="${HOME}/.pi/agent/extensions"
if [ -d "$PI_EXT_DIR" ] || command -v pi &>/dev/null; then
  mkdir -p "$PI_EXT_DIR"
  cp "$PLUGIN_DIR/extensions/tmux-status.ts" "$PI_EXT_DIR/"
  ok "extension → $PI_EXT_DIR/tmux-status.ts"
else
  skip "Pi" "not installed"
fi

# ── 4. Codex ──────────────────────────────────────────────────

printf '\n── Codex ──\n'
CODEX_INSTRUCTIONS="$HOME/.codex/instructions.md"
if command -v codex >/dev/null 2>&1; then
  mkdir -p "$(dirname "$CODEX_INSTRUCTIONS")"
  if [ -f "$CODEX_INSTRUCTIONS" ] && grep -q 'tmux-headline' "$CODEX_INSTRUCTIONS" 2>/dev/null; then
    skip "Codex" "already in instructions.md"
  else
    cat "$PLUGIN_DIR/codex-skill.md" >> "$CODEX_INSTRUCTIONS"
    ok "appended to $CODEX_INSTRUCTIONS"
  fi
else
  skip "Codex" "not installed"
fi

# ── summary ───────────────────────────────────────────────────

printf '\n══ %d ok, %d skipped, %d errors ══\n' "$OK" "$SKIP" "$ERR"

if [ "$ERR" -gt 0 ]; then
  exit 1
fi

if ! tmux info >/dev/null 2>&1; then
  printf '\nReload tmux config:  tmux source ~/.tmux.conf\n'
fi

printf 'Restart agent sessions for hooks/extensions to take effect.\n'
