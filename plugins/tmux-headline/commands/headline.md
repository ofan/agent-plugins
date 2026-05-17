---
description: Set the tmux pane headline. If no argument, read context and determine the label.
argument-hint: [2-4 lowercase words]
allowed-tools: Bash
---

If `$ARGUMENTS` is provided and valid (2-4 lowercase words, no punctuation), use it directly. If empty or invalid, determine a 2-4 word workstream label from the conversation context first, then set it.

Run exactly this:

```bash
TITLE="$ARGUMENTS"
PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"
if [ -z "$PANE" ]; then
  echo "not running inside tmux"
  exit 1
fi
# If no valid argument, Claude should have determined one from context above.
# The TITLE variable will contain the determined label.
if ! printf '%s' "$TITLE" | grep -qE '^[a-z]+( [a-z]+){1,3}$'; then
  echo "invalid title — needs 2 to 4 lowercase words, no punctuation: $TITLE"
  exit 1
fi
tmux select-pane -t "$PANE" -T "$TITLE"
tmux set-option -p -t "$PANE" @headline "$TITLE" 2>/dev/null || true
echo "headline → $TITLE"
```

After this command runs, the new label appears in the tmux pane border and window-tab status bar.
