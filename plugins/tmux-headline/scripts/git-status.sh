#!/usr/bin/env bash
# Compact git status for tmux: branch [+staged ~modified ?untracked]
DIR=${1:-$(pwd)}
cd "$DIR" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -z "$BRANCH" ] && exit 0

# Count changes
STATUS=$(git status --porcelain 2>/dev/null)
STAGED=$(echo "$STATUS" | grep -c '^[MADRC]')
MODIFIED=$(echo "$STATUS" | grep -c '^.[MD]')
UNTRACKED=$(echo "$STATUS" | grep -c '^??')

# Build indicators
IND=""
[ "$STAGED" -gt 0 ] && IND="${IND}+${STAGED}"
[ "$MODIFIED" -gt 0 ] && IND="${IND}~${MODIFIED}"
[ "$UNTRACKED" -gt 0 ] && IND="${IND}?${UNTRACKED}"

if [ -n "$IND" ]; then
  printf '%s %s' "$BRANCH" "$IND"
else
  printf '%s' "$BRANCH"
fi
