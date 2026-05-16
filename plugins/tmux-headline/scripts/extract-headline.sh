#!/usr/bin/env bash
# Generate a 2-3 word workstream headline from conversation context.
# Reads last N user messages, calls LLM to synthesize the workstream.
# Usage: extract-headline.sh <transcript_path>
set -euo pipefail

TRANSCRIPT="${1:-}"
[ ! -f "$TRANSCRIPT" ] && exit 0

# Extract last user messages for context (up to 8, max 200 chars each)
CONTEXT=$(python3 -c "
import json
msgs = []
try:
    with open('$TRANSCRIPT') as f:
        for line in f:
            try: d = json.loads(line.strip())
            except: continue
            role = d.get('role','') or d.get('message',{}).get('role','')
            if role not in ('human','user'): continue
            content = d.get('content','') or d.get('message',{}).get('content','')
            if isinstance(content, list):
                content = ' '.join(p.get('text','') for p in content if isinstance(p,dict))
            if content and isinstance(content, str):
                msgs.append(content.strip()[:200])
    print('\n---\n'.join(msgs[-8:]))
except: pass
" 2>/dev/null)

[ -z "$CONTEXT" ] && exit 0

# Call DeepSeek Flash to synthesize workstream label
HEADLINE=$(curl -sS --max-time 8 \
  -H "x-api-key: ${DEEPSEEK_API_KEY:-}" \
  -H "content-type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -X POST "https://api.deepseek.com/anthropic/v1/messages" \
  -d "$(python3 -c "
import json
ctx = json.dumps('''$CONTEXT''')
sys_prompt = 'You name coding workstreams. Output EXACTLY 2-3 lowercase words describing the PRIMARY task in this conversation. No punctuation. No explanation. Just the label.\n\nRules:\n- Synthesize the overall workstream from ALL messages, not just the last one\n- Examples: fix tmux spinner, add cost tracking, refactor proxy, debug oom, setup ingress\n- Use specific domain terms when clear (k8s, tmux, nginx, etc.)\n- Never repeat a prompt verbatim'
print(json.dumps({
    'model': 'deepseek-v4-flash',
    'max_tokens': 20,
    'temperature': 0,
    'system': sys_prompt,
    'messages': [{'role': 'user', 'content': f'Coding session messages:\n\n{ctx}\n\nWorkstream label:'}]
}))
")" 2>/dev/null | python3 -c "
import sys,json,re
try:
    d=json.load(sys.stdin)
    text = d['content'][0]['text'].strip().lower()
    words = re.findall(r'[a-z0-9]+', text)
    print(' '.join(words[:3]))
except: pass
" 2>/dev/null)

[ -n "$HEADLINE" ] && echo "$HEADLINE"