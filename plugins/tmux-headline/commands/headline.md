---
description: Set the tmux pane headline to a 2-4 word workstream label
argument-hint: <2 to 4 lowercase words>
allowed-tools: Bash
---

Set the tmux pane title to: `$ARGUMENTS`

Run exactly this:

```bash
TITLE="$ARGUMENTS"
PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"
if [ -z "$PANE" ]; then
  echo "not running inside tmux"
  exit 1
fi
# Validate: 2-4 lowercase words, no punctuation
if ! printf '%s' "$TITLE" | grep -qE '^[a-z]+( [a-z]+){1,3}$'; then
  echo "invalid title — needs 2 to 4 lowercase words, no punctuation: $TITLE"
  exit 1
fi
tmux select-pane -t "$PANE" -T "$TITLE"
echo "headline → $TITLE"
```

After this command runs, the new label appears in the tmux pane border and (if configured) in the window-tab status bar.
