#!/usr/bin/env bash
# Test tmux format rendering end-to-end.
# Creates a throwaway tmux session, sets pane titles + @agent, captures output.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_SESSION="headline-test-$$"
PASS=0 FAIL=0

cleanup() { tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true; }
trap cleanup EXIT

# ── helpers ───────────────────────────────────────────────────

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf '  ✓ %s\n' "$label"; ((PASS++))
  else
    printf '  ✗ %s\n    expected: %s\n    got:      %s\n' "$label" "$needle" "$haystack"; ((FAIL++))
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf '  ✓ %s\n' "$label"; ((PASS++))
  else
    printf '  ✗ %s (should NOT contain "%s")\n    got: %s\n' "$label" "$needle" "$haystack"; ((FAIL++))
  fi
}

fmt() { tmux display-message -p -t "$1" "$2" 2>/dev/null; }

capture_border() {
  local border_fmt
  border_fmt=$(tmux show -gv pane-border-format 2>/dev/null)
  [ -n "$border_fmt" ] && fmt "$1" "$border_fmt"
}

# ── setup ─────────────────────────────────────────────────────

printf 'Setting up test session...\n'
tmux new-session -d -s "$TEST_SESSION" -x 120 -y 24 "sleep 30"
sleep 0.3
bash "$PLUGIN_DIR/headline.tmux"
sleep 0.2
PANE=$(tmux list-panes -t "$TEST_SESSION" -F '#{pane_id}' | head -1)

# ── test 1: agent pane detection ──────────────────────────────

printf '\n── @agent detection ──\n'

# Without @agent, format should show #W
tmux select-pane -t "$PANE" -T "some title"
sleep 0.2
WIN_FMT=$(tmux show -gv window-status-format)
WIN_RENDERED=$(fmt "$PANE" "$WIN_FMT")
assert_not_contains "no @agent → no title in tab" "$WIN_RENDERED" "some title"

# With @agent, format should show pane_title
tmux set-option -p -t "$PANE" @agent 1
sleep 0.2
WIN_RENDERED=$(fmt "$PANE" "$WIN_FMT")
assert_contains "@agent → title in tab" "$WIN_RENDERED" "some title"

# ── test 2: Claude busy (flower glyphs) ──────────────────────

printf '\n── Claude busy: ✽ fix auth bug ──\n'
tmux select-pane -t "$PANE" -T "✽ fix auth bug"
sleep 0.2

TITLE=$(fmt "$PANE" '#{pane_title}')
assert_contains "pane_title set" "$TITLE" "✽ fix auth bug"

WIN_RENDERED=$(fmt "$PANE" "$WIN_FMT")
assert_contains "window tab shows flower + headline" "$WIN_RENDERED" "✽ fix auth bug"

BORDER=$(capture_border "$PANE")
assert_contains "border shows title" "$BORDER" "✽ fix auth bug"

# ── test 3: Claude idle ──────────────────────────────────────

printf '\n── Claude idle: · fix auth bug ──\n'
tmux select-pane -t "$PANE" -T "· fix auth bug"
sleep 0.2

WIN_RENDERED=$(fmt "$PANE" "$WIN_FMT")
assert_contains "window tab shows idle + headline" "$WIN_RENDERED" "· fix auth bug"

# ── test 4: Pi busy (braille) ────────────────────────────────

printf '\n── Pi busy: ⠋ refactor plugin ──\n'
tmux select-pane -t "$PANE" -T "⠋ refactor plugin"
sleep 0.2

WIN_RENDERED=$(fmt "$PANE" "$WIN_FMT")
assert_contains "window tab shows braille + headline" "$WIN_RENDERED" "refactor plugin"

# ── test 5: Pi idle ──────────────────────────────────────────

printf '\n── Pi idle: ⠿ refactor plugin ──\n'
tmux select-pane -t "$PANE" -T "⠿ refactor plugin"
sleep 0.2

WIN_RENDERED=$(fmt "$PANE" "$WIN_FMT")
assert_contains "window tab shows static + headline" "$WIN_RENDERED" "⠿ refactor plugin"

# ── test 6: session end ──────────────────────────────────────

printf '\n── Session end: cleared ──\n'
tmux select-pane -t "$PANE" -T ""
tmux set-option -p -t "$PANE" -u @agent
sleep 0.2

WIN_RENDERED=$(fmt "$PANE" "$WIN_FMT")
assert_not_contains "no headline in tab after end" "$WIN_RENDERED" "refactor"
assert_not_contains "no agent title after end" "$WIN_RENDERED" "⠿"

# ── test 7: title.sh helper ──────────────────────────────────

printf '\n── title.sh helper ──\n'
TMUX_PANE="$PANE" bash "$PLUGIN_DIR/scripts/title.sh" -p "$PANE" "✢ testing"
sleep 0.2
TITLE=$(fmt "$PANE" '#{pane_title}')
assert_contains "title.sh sets title" "$TITLE" "✢ testing"

TMUX_PANE="$PANE" bash "$PLUGIN_DIR/scripts/title.sh" -p "$PANE" ""
sleep 0.2
TITLE=$(fmt "$PANE" '#{pane_title}')
assert_contains "title.sh clears" "$TITLE" ""

# ── test 8: spinner outputs valid braille ─────────────────────

printf '\n── spinner.sh ──\n'
FRAME=$(bash "$PLUGIN_DIR/scripts/spinner.sh")
BRAILLE="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
if [[ "$BRAILLE" == *"$FRAME"* ]] && [ ${#FRAME} -gt 0 ]; then
  printf '  ✓ spinner outputs braille: %s\n' "$FRAME"; ((PASS++))
else
  printf '  ✗ spinner output not braille: %s\n' "$FRAME"; ((FAIL++))
fi

# ── results ───────────────────────────────────────────────────

printf '\n══ %d passed, %d failed ══\n' "$PASS" "$FAIL"
exit "$FAIL"
