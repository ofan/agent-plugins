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
        month_start=$(head -1 "$BALANCE_LOG" 2>/dev/null | cut -d' ' -f2 || echo "")
        if [ -n "$month_start" ] && [ "$month_start" != "$balance" ]; then
            monthly=$(python3 -c "print(f'{float($month_start)-float($balance):.2f}')" 2>/dev/null || echo "")
        fi
    fi
fi

# ── Display ──
parts=""
[ -n "$session" ] && [ "$session" != "0.00" ] && parts="s\$$session"
[ -n "$monthly" ] && [ "$monthly" != "0.00" ] && parts="$parts m\$$monthly"
[ -z "$parts" ] && [ -n "$balance" ] && parts="\$$balance"

echo "{\"ts\":$(date +%s),\"display\":\"$parts\",\"label\":\"ds\"}" > "$CACHE"
tmux set-option -g @cost_total "$parts" 2>/dev/null || true
