#!/bin/bash
# Validate a loop YAML file against the schema.
# Usage: validate-loop.sh <path-to-yaml>
# Returns 0 on valid, 1 on invalid with error messages.

set -euo pipefail

FILE="${1:-}"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Usage: validate-loop.sh <loop.yaml>"
  exit 1
fi

ERRORS=0

# Check required top-level fields
if ! grep -q "^name:" "$FILE"; then
  echo "ERROR: missing required field 'name'"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "^description:" "$FILE"; then
  echo "ERROR: missing required field 'description'"
  ERRORS=$((ERRORS + 1))
fi

if ! grep -q "^steps:" "$FILE"; then
  echo "ERROR: missing required field 'steps'"
  ERRORS=$((ERRORS + 1))
fi

# Check each step has a name
STEP_COUNT=$(grep -c "^  - name:" "$FILE" || echo 0)
if [ "$STEP_COUNT" -eq 0 ]; then
  echo "ERROR: no steps defined (steps must have 'name' field)"
  ERRORS=$((ERRORS + 1))
fi

# Check each step has at least one action type
while IFS= read -r step_name; do
  step_name=$(echo "$step_name" | sed 's/.*name: //')
  # Look for run:, action:, loop:, or loop-poll: after this step name
  if ! grep -A5 "name: $step_name" "$FILE" | grep -qE "^\s+(run|action|loop|loop-poll):"; then
    echo "WARNING: step '$step_name' has no execution type (run/action/loop/loop-poll)"
  fi
done < <(grep "^  - name:" "$FILE")

if [ "$ERRORS" -gt 0 ]; then
  echo "INVALID: $ERRORS error(s) found"
  exit 1
fi

echo "VALID: $(grep -c '^  - name:' "$FILE") steps"
exit 0
