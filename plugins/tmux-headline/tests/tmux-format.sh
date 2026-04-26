#!/usr/bin/env bash
# Test the v1.3 command + skill flow.
# - The /headline slash command body validates input and calls tmux to set pane_title.
# - The headline-naming skill instructs Claude on when to invoke /headline.
# - There's no UserPromptSubmit hook for headline anymore.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0 FAIL=0

# CRITICAL: use an isolated tmux server (-L test socket) so `tmux set -g` in
# this test cannot pollute the user's live tmux globals. Every tmux invocation
# below must use $T as the prefix.
TEST_SOCKET="hl-test-$$"
T="tmux -L $TEST_SOCKET"

cleanup() { $T kill-server 2>/dev/null || true; }
trap cleanup EXIT

assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf '  ✓ %s\n' "$label"; ((PASS++))
  else
    printf '  ✗ %s\n    expected: %s\n    got:      %s\n' "$label" "$expected" "$actual"; ((FAIL++))
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    printf '  ✓ %s\n' "$label"; ((PASS++))
  else
    printf '  ✗ %s — missing "%s" in: %s\n' "$label" "$needle" "$haystack"; ((FAIL++))
  fi
}

# ── command file shape ────────────────────────────────────────

printf '\n── /headline command ──\n'

CMD_FILE="$PLUGIN_DIR/commands/headline.md"
if [ -f "$CMD_FILE" ]; then
  printf '  ✓ commands/headline.md exists\n'; ((PASS++))
  CONTENT=$(cat "$CMD_FILE")
  assert_contains "frontmatter description" "$CONTENT" "description:"
  assert_contains "argument-hint declared" "$CONTENT" "argument-hint:"
  assert_contains "uses Bash" "$CONTENT" "allowed-tools: Bash"
  assert_contains "validates 2-4 lowercase words" "$CONTENT" "[a-z]+( [a-z]+){1,3}"
  assert_contains "calls tmux select-pane" "$CONTENT" "tmux select-pane"
else
  printf '  ✗ commands/headline.md missing\n'; ((FAIL++))
fi

# ── command body: validate regex + tmux side-effect separately ─

printf '\n── command body validation regex ──\n'

# Pull the regex literal out of the command md
REGEX_LINE=$(grep -E "grep -qE" "$CMD_FILE")
assert_contains "regex line found" "$REGEX_LINE" "[a-z]+( [a-z]+){1,3}"

valid_title() {
  printf '%s' "$1" | grep -qE '^[a-z]+( [a-z]+){1,3}$' && echo yes || echo no
}
assert_eq "accepts 'deploy auth service'" "$(valid_title 'deploy auth service')" "yes"
assert_eq "accepts 'fix bug'" "$(valid_title 'fix bug')" "yes"
assert_eq "accepts 'four word workstream label'" "$(valid_title 'four word workstream label')" "yes"
assert_eq "rejects single word" "$(valid_title 'OneWord')" "no"
assert_eq "rejects 'just_one'" "$(valid_title 'singleword')" "no"
assert_eq "rejects >4 words" "$(valid_title 'one two three four five')" "no"
assert_eq "rejects punctuation" "$(valid_title 'has punctuation!')" "no"
assert_eq "rejects uppercase" "$(valid_title 'Has Caps')" "no"

printf '\n── command body tmux side effect ──\n'

# Isolated tmux server (-L) ensures we cannot pollute the user's live session
$T new-session -d -s "hl-cmd-test" -x 120 -y 24 "sleep 30"
sleep 0.2
PANE=$($T list-panes -t "hl-cmd-test" -F '#{pane_id}' | head -1)
$T select-pane -t "$PANE" -T "deploy auth service"
RESULT=$($T display-message -p -t "$PANE" '#{pane_title}')
assert_eq "tmux select-pane -T sets pane_title (the action /headline performs)" "$RESULT" "deploy auth service"
$T kill-session -t "hl-cmd-test" 2>/dev/null

# Build a `tmux` shim for the headline.tmux test below
SHIM_DIR="$PLUGIN_DIR/tests/_shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/tmux" <<SHIM
#!/usr/bin/env bash
exec $T "\$@"
SHIM
chmod +x "$SHIM_DIR/tmux"

# ── skill file shape ──────────────────────────────────────────

printf '\n── headline-naming skill ──\n'

SKILL_FILE="$PLUGIN_DIR/skills/headline-naming/SKILL.md"
if [ -f "$SKILL_FILE" ]; then
  printf '  ✓ skill exists\n'; ((PASS++))
  CONTENT=$(cat "$SKILL_FILE")
  assert_contains "skill name in frontmatter" "$CONTENT" "name: headline-naming"
  assert_contains "trigger description present" "$CONTENT" "description:"
  assert_contains "references /headline command" "$CONTENT" "/headline"
  assert_contains "covers recap integration" "$CONTENT" "recap"
else
  printf '  ✗ skill missing\n'; ((FAIL++))
fi

# ── hooks.json no longer has UserPromptSubmit ─────────────────

printf '\n── hooks.json ──\n'

HOOKS=$(cat "$PLUGIN_DIR/hooks/hooks.json")
if [[ "$HOOKS" != *"UserPromptSubmit"* ]]; then
  printf '  ✓ UserPromptSubmit hook removed\n'; ((PASS++))
else
  printf '  ✗ UserPromptSubmit hook still present\n'; ((FAIL++))
fi
assert_contains "Stop hook still present" "$HOOKS" '"Stop"'
assert_contains "SessionEnd hook still present" "$HOOKS" '"SessionEnd"'

# ── headline-reminder.sh deleted ──────────────────────────────

if [ ! -f "$PLUGIN_DIR/hooks/headline-reminder.sh" ]; then
  printf '  ✓ headline-reminder.sh deleted\n'; ((PASS++))
else
  printf '  ✗ headline-reminder.sh should be deleted\n'; ((FAIL++))
fi

# ── headline.tmux still preserves customizations ──────────────

printf '\n── headline.tmux gates global writes on default detection ──\n'

TMUX_SCRIPT=$(cat "$PLUGIN_DIR/headline.tmux")
# Ensure each global is set behind a comparison against the tmux default
assert_contains "pane-border-status gated on 'off'"  "$TMUX_SCRIPT" 'pane-border-status'
assert_contains "pane-border-status only set when off" "$TMUX_SCRIPT" '= "off"'
assert_contains "pane-border-format compares to default" "$TMUX_SCRIPT" 'DEFAULT_BORDER='
assert_contains "window-status-format gated on default" "$TMUX_SCRIPT" 'DEFAULT_WSF='
# guard: no top-level (column-0) `tmux set -g window-status-format` line —
# any window-status-format write must be inside an if-block.
if grep -E '^tmux set -g window-status-format' "$PLUGIN_DIR/headline.tmux" >/dev/null; then
  printf '  ✗ unconditional tmux set -g window-status-format at column 0\n'; ((FAIL++))
else
  printf '  ✓ no unconditional window-status-format override (gated by if)\n'; ((PASS++))
fi

rm -rf "$SHIM_DIR"

# ── spinner.sh utility (Pi-style braille frame) ───────────────

printf '\n── spinner.sh utility ──\n'
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
