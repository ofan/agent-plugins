#!/usr/bin/env bash
# Extract a 1-3 word headline from conversation transcript.
# Supports both Claude Code (role at top level) and Pi (nested message.role) formats.
# Usage: extract-headline.sh <transcript_path> [current_headline]
set -euo pipefail

TRANSCRIPT="$1"
CURRENT="${2:-}"

[ ! -f "$TRANSCRIPT" ] && exit 0

HEADLINE=$(python3 -c "
import json, re, sys

STOP = {'a','an','the','and','or','but','in','on','at','to','for','of','is','it',
        'can','you','please','could','would','should','do','did','this','that',
        'my','me','i','we','our','be','have','has','had','will','just','also',
        'with','from','into','about','not','no','so','if','when','how','what',
        'why','where','which','some','all','any','up','out','now','then','here',
        'there','very','really','let','got','go','going','want','need','try',
        'using','look','sure','know','think','see','hey','hi','hello','its',
        'like','been','was','were','are','does','done','too','more','still',
        'headline','title','spinner','idle','busy','correct','fix','test'}

last = ''
try:
    with open(sys.argv[1]) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Claude Code format: {role: 'human', content: ...}
            role = msg.get('role', '')
            content = msg.get('content', '')

            # Pi format: {type: 'message', message: {role: 'user', content: [...]}}
            if not role and msg.get('type') == 'message':
                inner = msg.get('message', {})
                role = inner.get('role', '')
                content = inner.get('content', '')

            if role not in ('human', 'user'):
                continue

            if isinstance(content, list):
                content = ' '.join(p.get('text','') for p in content if isinstance(p, dict))
            if isinstance(content, str) and content.strip():
                last = content.strip()
except Exception:
    pass

if not last:
    sys.exit(0)

words = re.findall(r'[a-z]+', last.lower())
keep = [w for w in words if w not in STOP and len(w) > 1]
print(' '.join(keep[:3]))
" "$TRANSCRIPT" 2>/dev/null) || true

[ -z "$HEADLINE" ] && exit 0
[ "$HEADLINE" = "$CURRENT" ] && exit 0

echo "$HEADLINE"
