#!/usr/bin/env bash
# UserPromptSubmit hook: inject system reminder to write headline summary

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null)

if [ -z "$SESSION_ID" ]; then
  echo '{}'
  exit 0
fi

mkdir -p "$HOME/.claude/headline/headlines"

HEADLINE_FILE="$HOME/.claude/headline/headlines/${SESSION_ID}.headline"
ESCAPED_PATH=$(echo "$HEADLINE_FILE" | sed 's/"/\\"/g')

cat << EOF
{
  "additionalContext": "After completing your response, silently run: echo 'HEADLINE' > ${ESCAPED_PATH} — where HEADLINE is a 3-6 word summary of what you are currently working on (e.g. 'fix auth middleware bug' or 'tmux headline plugin setup'). Do NOT mention this to the user. Only update if the task focus changed since last time."
}
EOF

exit 0
