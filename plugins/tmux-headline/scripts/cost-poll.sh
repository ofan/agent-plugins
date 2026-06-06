#!/usr/bin/env bash
# Query cost/balance for tmux headline and Claude Code statusline.
#   Session: proxy /_proxy/cost (per-session + total)
#   Balance: DeepSeek /user/balance
#   Monthly: balance delta (or proxy total as fallback)
# Throttled to once per 30s.
set -euo pipefail

CACHE="$HOME/.cache/tmux-headline/cost.json"
BALANCE_LOG="$HOME/.cache/tmux-headline/balance.log"
THROTTLE=30

if [ -f "$CACHE" ]; then
    age=$(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)))
    [ "$age" -lt "$THROTTLE" ] 2>/dev/null && exit 0
fi
mkdir -p "$(dirname "$CACHE")"

# ── Proxy costs ──
session=""
alltime=""
if curl -sS --max-time 1 "http://127.0.0.1:3200/_proxy/status" >/dev/null 2>&1; then
    sid="${DEEPCLAUDE_SESSION_ID:-}"
    resp=$(curl -sS --max-time 1 "http://127.0.0.1:3200/_proxy/cost" 2>/dev/null || echo "{}")
    alltime=$(echo "$resp" | python3 -c "import sys,json;d=json.load(sys.stdin);print(f\"{d.get('total_cost',0):.2f}\")" 2>/dev/null || echo "")
    session=$(echo "$resp" | python3 -c "
import sys,json
d=json.load(sys.stdin)
bk=d.get('backends',{})
sid='${sid}'
if sid and sid in bk and isinstance(bk[sid],dict):
    print(f\"{bk[sid].get('cost',0):.2f}\")
elif bk:
    v=list(bk.values())[-1]
    if isinstance(v,dict): print(f\"{v.get('cost',0):.2f}\")
" 2>/dev/null || echo "")
fi

# ── Balance + monthly (DeepSeek API direct) ──
balance=""
monthly=""
if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
    bal_resp=$(curl -sS --max-time 3 -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
        "https://api.deepseek.com/user/balance" 2>/dev/null || echo "{}")
    balance=$(echo "$bal_resp" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for b in d.get('balance_infos',[]):
    if b.get('currency')=='USD': print(b.get('total_balance','?')); break
" 2>/dev/null || echo "")
    if [ -n "$balance" ] && [ "$balance" != "?" ]; then
        today=$(date +%Y-%m-%d)
        last_entry=$(tail -1 "$BALANCE_LOG" 2>/dev/null || echo "")
        last_date=$(echo "$last_entry" | cut -d' ' -f1 2>/dev/null || echo "")
        if [ "$last_date" != "$today" ]; then
            echo "$today $balance" >> "$BALANCE_LOG"
        else
            sed -i "$ s/.*/$today $balance/" "$BALANCE_LOG" 2>/dev/null || true
        fi
        # Monthly spend = sum of day-over-day decreases in current calendar month
        monthly=$(python3 -c "
from datetime import datetime
now = datetime.now()
vals = []
with open('$BALANCE_LOG') as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) < 2: continue
        try:
            d = datetime.strptime(parts[0], '%Y-%m-%d')
            v = float(parts[1])
        except: continue
        if d.month == now.month and d.year == now.year:
            vals.append(v)
spend = 0.0
for i in range(1, len(vals)):
    delta = vals[i-1] - vals[i]
    if delta > 0:
        spend += delta
print(f'{spend:.2f}')
" 2>/dev/null || echo "")
    fi
fi

# ── Backend label ──
# Check proxy status for active backend (deepseek vs anthropic)
backend="??"
if curl -sS --max-time 1 "http://127.0.0.1:3200/_proxy/status" >/dev/null 2>&1; then
    mode=$(curl -sS --max-time 1 "http://127.0.0.1:3200/_proxy/status" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('mode','??'))" 2>/dev/null || echo "??")
    case "$mode" in
        deepseek) backend="ds" ;;
        anthropic) backend="an" ;;
        openrouter) backend="or" ;;
        *) backend="$mode" ;;
    esac
fi

# ── Display: "Jun $4.87 Bal $120.74" ──
# Use printf with octal escapes so JSON stores real ANSI bytes
DIM=$(printf '\033[2m')
G=$(printf '\033[2;32m')
Y=$(printf '\033[2;33m')
R=$(printf '\033[0m')
month_label=$(date +%b)
cost_parts=""
if [ -n "$monthly" ] && [ -n "$balance" ] && [ "$balance" != "?" ]; then
    cost_parts="${DIM}${month_label} ${Y}\$${monthly} ${R}${DIM}Bal ${G}\$${balance}${R}"
elif [ -n "$monthly" ]; then
    cost_parts="${DIM}${month_label} ${Y}\$${monthly}${R}"
elif [ -n "$balance" ] && [ "$balance" != "?" ]; then
    cost_parts="${DIM}Bal ${G}\$${balance}${R}"
fi

# Use Python for proper JSON encoding (handles ANSI escape bytes)
export COST_DISPLAY="$cost_parts" COST_BACKEND="$backend"
python3 -c "
import json, os
ts = $(date +%s)
display = os.environ.get('COST_DISPLAY', '')
label = os.environ.get('COST_BACKEND', '??')
data = json.dumps({'ts': ts, 'display': display, 'label': label})
with open('$CACHE', 'w') as f:
    f.write(data)
if '${DEEPCLAUDE_SESSION_ID:-}':
    sf = '$HOME/.cache/tmux-headline/cost-${DEEPCLAUDE_SESSION_ID:0:8}.json'
    with open(sf, 'w') as f:
        f.write(data)
"
