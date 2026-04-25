#!/usr/bin/env bash
# UserPromptSubmit hook: extract a ≤4-word compressed headline from the
# user's prompt and return it as `sessionTitle` in hookSpecificOutput.
# Claude Code applies it natively (same effect as /rename) — its own
# cycling spinner continues to drive pane_title with our short text.
#
# No daemons, no file writes, no race with Claude — Claude does it all.

set -euo pipefail

INPUT=$(cat)
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
        # ack/filler words — keep prior headline rather than clobber with these
        "yes","yeah","yep","ok","okay","alright","thanks","thank","cool","nice"}

def compress(text: str) -> str:
    words = re.findall(r"[a-z]+", text.lower())
    keep = [w for w in words if w not in STOP and len(w) > 1]
    return " ".join(keep[:4])

try:
    data = json.load(sys.stdin)
except Exception:
    print("{}")
    sys.exit(0)

prompt = data.get("prompt") or ""
current = (data.get("session_title") or "").strip().lower()
title = compress(prompt)

# Skip if extraction empty or unchanged
if not title or title == current:
    print("{}")
    sys.exit(0)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "sessionTitle": title
    }
}))
'
