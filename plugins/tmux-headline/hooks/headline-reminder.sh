#!/usr/bin/env bash
# UserPromptSubmit hook: extract a ≤4-word compressed headline from the
# user's prompt and return it as `sessionTitle` in hookSpecificOutput.
# Claude Code applies it natively (same effect as /rename) — its own
# cycling spinner continues to drive pane_title with our short text.
#
# Stickiness policy (v1.2.2): the headline should track the workstream,
# not every prompt. We keep the current title unless the new candidate
# meets BOTH:
#   - has ≥ MIN_WORDS informative words
#   - has low word-overlap with the current title (Jaccard < OVERLAP_MAX)
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

MIN_WORDS = 2     # candidate must have at least this many informative words
MAX_WORDS = 4     # title is capped at this many
OVERLAP_MAX = 0.34  # Jaccard similarity threshold — below = treat as topic shift

def informative(text: str) -> list[str]:
    words = re.findall(r"[a-z]+", text.lower())
    return [w for w in words if w not in STOP and len(w) > 1]

def should_update(current: str, candidate_words: list[str]) -> bool:
    """Return True if the candidate represents a workstream change worth committing."""
    if len(candidate_words) < MIN_WORDS:
        return False
    cur_words = set(informative(current))
    if not cur_words:
        return True  # no current title yet — anything informative wins
    new_words = set(candidate_words)
    union = cur_words | new_words
    overlap = len(cur_words & new_words) / len(union)
    return overlap < OVERLAP_MAX

try:
    data = json.load(sys.stdin)
except Exception:
    print("{}")
    sys.exit(0)

prompt = data.get("prompt") or ""
current = (data.get("session_title") or "").strip()
words = informative(prompt)
title = " ".join(words[:MAX_WORDS])

if not title or title == current.lower() or not should_update(current, words):
    print("{}")
    sys.exit(0)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "sessionTitle": title
    }
}))
'
