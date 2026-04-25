#!/usr/bin/env bash
# Test the v1.2 sessionTitle-based headline flow.
#
# Verifies headline-reminder.sh (UserPromptSubmit) emits the correct
# hookSpecificOutput JSON for various inputs, and that the tmux format
# script applies safely without overriding user customizations.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/headline-reminder.sh"
PASS=0 FAIL=0

assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  ✓ %s\n' "$label"; ((PASS++))
  else
    printf '  ✗ %s\n    expected: %s\n    got:      %s\n' "$label" "$expected" "$actual"; ((FAIL++))
  fi
}

assert_json_field() {
  local label="$1" json="$2" path="$3" expected="$4"
  local got
  got=$(echo "$json" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    for k in '$path'.split('.'):
        d = d.get(k) if isinstance(d, dict) else None
        if d is None: break
    print(d if d is not None else '')
except: print('')
")
  assert_eq "$label" "$got" "$expected"
}

run_hook() {
  echo "$1" | bash "$HOOK"
}

# ── headline extraction & JSON output ─────────────────────────

printf '\n── sessionTitle output ──\n'

OUT=$(run_hook '{"prompt":"please fix the overly long claude headlines extra words","session_title":""}')
assert_json_field "extracts ≤4-word headline" "$OUT" \
  "hookSpecificOutput.sessionTitle" "fix overly long claude"

OUT=$(run_hook '{"prompt":"add cycling spinner with claude glyphs","session_title":""}')
assert_json_field "stopwords filtered" "$OUT" \
  "hookSpecificOutput.sessionTitle" "add cycling spinner claude"

OUT=$(run_hook '{"prompt":"add cycling spinner with claude glyphs","session_title":"add cycling spinner claude"}')
assert_eq "no-op when title unchanged" "$OUT" "{}"

OUT=$(run_hook '{"prompt":"yes ok thanks","session_title":""}')
assert_eq "ack-only prompt → no-op (preserve prior title)" "$OUT" "{}"

OUT=$(run_hook 'not-json')
assert_eq "malformed JSON → no-op (no crash)" "$OUT" "{}"

OUT=$(run_hook '')
assert_eq "empty stdin → no-op" "$OUT" "{}"

OUT=$(run_hook '{"prompt":"","session_title":"existing"}')
assert_eq "empty prompt → no-op" "$OUT" "{}"

# ── hookEventName must be set correctly ────────────────────────

printf '\n── hookSpecificOutput envelope ──\n'

OUT=$(run_hook '{"prompt":"build the new feature","session_title":""}')
assert_json_field "hookEventName is UserPromptSubmit" "$OUT" \
  "hookSpecificOutput.hookEventName" "UserPromptSubmit"

# ── extract-headline.sh (still used by Pi) ─────────────────────

printf '\n── extract-headline.sh transcript path (Pi compatibility) ──\n'
TX=$(mktemp)
cat > "$TX" <<'EOF'
{"role":"user","content":"please refactor authentication module to support oauth providers"}
EOF
EXTRACTED=$(bash "$PLUGIN_DIR/scripts/extract-headline.sh" "$TX")
rm -f "$TX"
WC=$(echo "$EXTRACTED" | awk '{print NF}')
if [ "$WC" -ge 1 ] && [ "$WC" -le 4 ]; then
  printf '  ✓ extracted %d words (≤4): %s\n' "$WC" "$EXTRACTED"; ((PASS++))
else
  printf '  ✗ extracted %d words: %s\n' "$WC" "$EXTRACTED"; ((FAIL++))
fi

# ── spinner.sh utility (Pi-style braille frame) ───────────────

printf '\n── spinner.sh utility ──\n'
FRAME=$(bash "$PLUGIN_DIR/scripts/spinner.sh")
BRAILLE="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
if [[ "$BRAILLE" == *"$FRAME"* ]] && [ ${#FRAME} -gt 0 ]; then
  printf '  ✓ spinner outputs braille: %s\n' "$FRAME"; ((PASS++))
else
  printf '  ✗ spinner output not braille: %s\n' "$FRAME"; ((FAIL++))
fi

# ── headline.tmux is conservative about globals ───────────────

printf '\n── headline.tmux preserves customizations ──\n'
TS="hl-tmux-test-$$"
tmux new-session -d -s "$TS" -x 120 -y 24 "sleep 30"
sleep 0.2

# User's pre-existing custom format
CUSTOM='#{?pane_active,>>>,} #{pane_index}:#{pane_current_command}'
tmux set -g pane-border-format "$CUSTOM"
tmux set -g window-status-format "$CUSTOM"
bash "$PLUGIN_DIR/headline.tmux" 2>/dev/null
RESULT=$(tmux show -gv pane-border-format)
assert_eq "respects user's pane-border-format" "$RESULT" "$CUSTOM"
RESULT=$(tmux show -gv window-status-format)
assert_eq "respects user's window-status-format" "$RESULT" "$CUSTOM"

tmux kill-session -t "$TS" 2>/dev/null

# ── headline.tmux applies window-tab format on default tmux ──
printf '\n── headline.tmux applies on default tmux ──\n'
TS="hl-tmux-default-$$"
tmux new-session -d -s "$TS" -x 120 -y 24 "sleep 30"
sleep 0.2
# Reset to tmux defaults
tmux set -gu window-status-format
tmux set -gu pane-border-format
bash "$PLUGIN_DIR/headline.tmux" 2>/dev/null
RESULT=$(tmux show -gv window-status-format)
if [[ "$RESULT" == *"pane_title"* ]]; then
  printf '  ✓ window-status-format includes pane_title: %s\n' "$RESULT"; ((PASS++))
else
  printf '  ✗ window-status-format missing pane_title: %s\n' "$RESULT"; ((FAIL++))
fi
tmux kill-session -t "$TS" 2>/dev/null

# ── results ───────────────────────────────────────────────────
printf '\n══ %d passed, %d failed ══\n' "$PASS" "$FAIL"
exit "$FAIL"
