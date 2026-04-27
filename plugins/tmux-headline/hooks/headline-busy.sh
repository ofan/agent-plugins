#!/usr/bin/env bash
# UserPromptSubmit hook with two responsibilities:
#   1. State: set per-pane @claude_busy=1 so headline-render.sh cycles.
#   2. Stickiness guard: keep sessionTitle from being clobbered by Claude
#      Code's auto-title fallback when the user types a meta/short prompt.
#
# The smart renaming path is the /headline command + naming skill — those
# stay authoritative for genuine workstream shifts. This hook only emits
# a sessionTitle when:
#   - the user's prompt yields ≥2 informative words (compress + emit), OR
#   - the current sessionTitle is already a good ≥2-word label (re-emit
#     to prevent firstPrompt fallback from overwriting it).
# Otherwise emits {} and lets things alone.

set -euo pipefail

INPUT=$(cat)

# 1. Mark pane busy
if [ -n "${TMUX_PANE:-}" ]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_busy 1 2>/dev/null || true
fi

# 2. Stickiness guard
echo "$INPUT" | python3 -c '
import json, re, sys

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

def compress(text):
    words = re.findall(r"[a-z]+", text.lower())
    keep = [w for w in words if w not in STOP and len(w) > 1]
    return " ".join(keep[:MAX_WORDS])

try:
    data = json.load(sys.stdin)
except Exception:
    print("{}"); sys.exit(0)

prompt = data.get("prompt") or ""
current = (data.get("session_title") or "").strip()
candidate = compress(prompt)

cand_words = len(candidate.split())
cur_words = len(current.split())

# Pick: candidate if good, else current if good, else nothing
if cand_words >= MIN_WORDS:
    emit = candidate
elif cur_words >= MIN_WORDS:
    emit = current
else:
    emit = ""

if not emit:
    print("{}"); sys.exit(0)

# Always emit when we have a good label — even if equal to the reported
# current — so Claude Code persists customTitle and the firstPrompt
# fallback can never re-clobber the headline on a meta/short prompt.
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "sessionTitle": emit
    }
}))
'
