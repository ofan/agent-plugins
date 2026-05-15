#!/usr/bin/env bash
# UserPromptSubmit hook with two responsibilities:
#   1. State: set per-pane @claude_busy=1 so headline-render.sh cycles.
#   2. Stickiness guard: prevent Claude Code's firstPrompt fallback from
#      degrading sessionTitle to a single user word ("tldr", "test").
#
# The smart renaming path is the /headline command + naming skill. This
# hook is just a guard against degradation. It picks sessionTitle by
# preference:
#   1. compressed candidate from this prompt (if ≥2 informative words)
#   2. current sessionTitle (if ≥2 words)
#   3. saved last-good title from per-session file (if any)
# A successful pick is also written to the state file so future degraded
# turns can recover from it.

set -euo pipefail

INPUT=$(cat)

# 1. Mark pane busy
if [ -n "${TMUX_PANE:-}" ]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_busy 1 2>/dev/null || true
fi

# 2. Stickiness guard
OUTPUT=$(echo "$INPUT" | python3 -c '
import json, os, re, sys

STOP = {"a","an","the","and","or","but","in","on","at","to","for","of","is","it",
        "can","you","please","could","would","should","do","did","this","that",
        "my","me","i","we","our","be","have","has","had","will","just","also",
        "with","from","into","about","not","no","so","if","when","how","what",
        "why","where","which","some","all","any","up","out","now","then","here",
        "there","very","really","let","got","go","going","want","need","try",
        "using","look","sure","know","think","see","hey","hi","hello","its",
        "like","been","was","were","are","does","done","too","more","still",
        "yes","yeah","yep","ok","okay","alright","thanks","thank","cool","nice"}

MIN_WORDS = 2
MAX_WORDS = 4
DATA_DIR = os.path.expanduser("~/.local/share/tmux-headline/headlines")

def compress(text):
    words = re.findall(r"[a-z]+", text.lower())
    keep = [w for w in words if w not in STOP and len(w) > 1]
    return " ".join(keep[:MAX_WORDS])

try:
    data = json.load(sys.stdin)
except Exception:
    print("{}"); sys.exit(0)

prompt   = data.get("prompt") or ""
current  = (data.get("session_title") or "").strip()
sid      = data.get("session_id") or ""

# Per-session state file: remembers the last good headline so meta prompts
# can recover after a degradation.
state_path = os.path.join(DATA_DIR, f"{sid}.last_good") if sid else None
last_good = ""
if state_path and os.path.exists(state_path):
    try:
        with open(state_path) as f:
            last_good = f.read().strip()
    except Exception:
        pass

candidate = compress(prompt)
cand_words = len(candidate.split())
cur_words  = len(current.split())

if cand_words >= MIN_WORDS:
    emit = candidate
elif cur_words >= MIN_WORDS:
    emit = current
elif last_good:
    emit = last_good
else:
    emit = ""

if not emit:
    print("{}"); sys.exit(0)

# Persist any successful pick — this is what makes recovery possible.
if state_path:
    try:
        os.makedirs(DATA_DIR, exist_ok=True)
        with open(state_path, "w") as f:
            f.write(emit)
    except Exception:
        pass

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "sessionTitle": emit
    }
}))
')

# Extract headline from hook output and set @headline for tmux tabs
HEADLINE=$(echo "$OUTPUT" | python3 -c "
import json,sys
try:
    d = json.load(sys.stdin)
    print(d.get('hookSpecificOutput',{}).get('sessionTitle',''))
except: pass
" 2>/dev/null)
if [ -n "$HEADLINE" ] && [ -n "${TMUX_PANE:-}" ]; then
    tmux set-option -p -t "$TMUX_PANE" @headline "$HEADLINE" 2>/dev/null || true
fi

echo "$OUTPUT"
