---
description: Read the conversation and set a tmux headline describing the current workstream
allowed-tools: Bash
---

Read the conversation context. Determine the primary workstream. Then set the tmux headline:

```bash
TITLE="<2-4 lowercase words describing the workstream goal>"
PANE="${TMUX_PANE:-$(tmux display-message -p '#{pane_id}' 2>/dev/null)}"
if [ -z "$PANE" ]; then
  echo "not inside tmux"
  exit 1
fi
tmux select-pane -t "$PANE" -T "$TITLE"
tmux set-option -p -t "$PANE" @headline "$TITLE" 2>/dev/null || true
echo "headline → $TITLE"
```

Replace `<2-4 lowercase words describing the workstream goal>` with a label you determine from the conversation. Rules:
- 2-4 lowercase words, no punctuation
- Name the GOAL or subject, not the specific question
- Skip if the current headline already matches
