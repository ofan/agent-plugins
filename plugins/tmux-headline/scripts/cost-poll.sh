#!/usr/bin/env bash
# Query usage/cost for tmux headline.
#   DeepSeek:  proxy session cost → fallback balance API
#   Anthropic: direct rate-limit header poll
# Throttled to once per 30s. Sets @cost_total and @cost_label.
set -euo pipefail

CACHE="$HOME/.cache/tmux-headline/cost.json"
THROTTLE=30

if [ -f "$CACHE" ]; then
    age=$(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null || stat -f %m "$CACHE" 2>/dev/null || echo 0)))
    [ "$age" -lt "$THROTTLE" ] 2>/dev/null && exit 0
fi
mkdir -p "$(dirname "$CACHE")"

deepseek_poll() {
    [ -n "${DEEPSEEK_API_KEY:-}" ] || return 1

    # 1. Proxy session cost (fast, accurate, ~1ms local)
    local proxy_resp total
    proxy_resp=$(curl -sS --max-time 1 "http://127.0.0.1:3200/_proxy/cost" 2>/dev/null || echo "")
    if [ -n "$proxy_resp" ]; then
        total=$(echo "$proxy_resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"{d.get('total_cost',0):.2f}\")" 2>/dev/null || echo "")
    fi

    # 2. Fallback: DeepSeek balance API (~200ms remote)
    if [ -z "${total:-}" ]; then
        local balance
        balance=$(curl -sS --max-time 3 -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
            "https://api.deepseek.com/user/balance" 2>/dev/null || echo "{}")
        total=$(echo "$balance" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for b in d.get('balance_infos',[]):
    if b.get('currency')=='USD':
        print(b.get('total_balance','?'))
        break
" 2>/dev/null || echo "?")
    fi

    echo "{\"ts\":$(date +%s),\"display\":\"\$${total:-?}\",\"label\":\"ds\"}" > "$CACHE"
    tmux set-option -g @cost_total "\$${total:-?}" 2>/dev/null || true
    tmux set-option -g @cost_label "ds" 2>/dev/null || true
}

anthropic_poll() {
    local token=""
    if [ -f "$HOME/.claude/.credentials.json" ]; then
        token=$(python3 -c "
import json, time
try:
    with open('$HOME/.claude/.credentials.json') as f: c = json.load(f)
    o = c.get('claudeAiOauth', {})
    if o.get('expiresAt',0)/1000 > time.time(): print(o.get('accessToken',''))
except: pass
" 2>/dev/null)
    fi
    [ -z "$token" ] && [ -n "${ANTHROPIC_API_KEY:-}" ] && token="$ANTHROPIC_API_KEY"
    [ -z "$token" ] && return 1

    local resp
    resp=$(curl -sS --max-time 5 -X POST "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: $token" -H "content-type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"x"}]}' \
        -i 2>/dev/null || echo "")

    local pct_5h=$(echo "$resp" | grep -i 'anthropic-ratelimit-unified-5h-utilization' | cut -d: -f2 | tr -d ' \r' || echo "0")
    local pct_int=$(python3 -c "print(f'{float(${pct_5h:-0})*100:.0f}%')" 2>/dev/null || echo "?%")
    local status=$(echo "$resp" | grep -i 'anthropic-ratelimit-unified-status' | cut -d: -f2 | tr -d ' \r' || echo "?")

    echo "{\"ts\":$(date +%s),\"display\":\"$pct_int\",\"label\":\"an\",\"status\":\"$status\"}" > "$CACHE"
    tmux set-option -g @cost_total "$pct_int" 2>/dev/null || true
    tmux set-option -g @cost_label "an" 2>/dev/null || true
}

# Check if proxy is running (DeepSeek/OpenRouter session).
# If so, proxy cost is the most accurate — no API key needed.
if curl -sS --max-time 1 "http://127.0.0.1:3200/_proxy/status" >/dev/null 2>&1; then
    deepseek_poll
elif [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -f "$HOME/.claude/.credentials.json" ]; then
    anthropic_poll
fi
