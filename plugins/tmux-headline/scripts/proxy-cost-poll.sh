#!/usr/bin/env bash
# Poll llm-proxy billing for the ACTIVE model's provider and cache a one-line
# usage/limit display for the statusline.
#
# Display order: 5h rate → period/weekly quota → other windows → mcp % → balance
#   5h + period + other: bars with reset timer
#   MCP: plain %, no bar
#   Balance: $X.XX (only when extra_credits exists)
#
# Active model from stdin (Claude Code .model.id) or PROXY_ACTIVE_MODEL env.
# Sources: /v1/models (model→backend resolution) + /_/billing (quota windows).
# Caches (under ~/.cache/tmux-headline):
#   proxy-cost.json   — rendered display + provider, 60s throttle, invalidated
#                       on provider/model switch so bars always match the model
#   proxy-models.json — /v1/models catalog, 1h TTL (bare-id → backend lookup)
#
# Cross-platform: Python 3 does all parsing/date math (no GNU stat, no bash
# heredoc quirks). Runs under bash/dash on Linux, macOS, Git Bash, WSL.
set -eu

# Billing base URL. Priority: explicit LLM_PROXY_URL → the ANTHROPIC_BASE_URL
# Claude Code already exports to the statusline env (that's the proxy actually
# in use, incl. its http/https scheme) → hardcoded default. Nothing sets
# LLM_PROXY_URL today, so in practice this follows ANTHROPIC_BASE_URL.
PROXY="${LLM_PROXY_URL:-${ANTHROPIC_BASE_URL:-http://proxy.lab.tf}}"
CACHE_DIR="$HOME/.cache/tmux-headline"
CACHE="$CACHE_DIR/proxy-cost.json"
CATALOG_CACHE="$CACHE_DIR/proxy-models.json"
THROTTLE=60

PY="$(command -v python3 || command -v python || true)"
[ -z "$PY" ] && exit 0

# Read the statusLine JSON from stdin ONCE, up front, so we can derive the
# active model's provider BEFORE the throttle check. Without this, a model
# switch would be hidden behind the age-based throttle and the bars would keep
# showing the PREVIOUS model's limit/usage for up to THROTTLE seconds.
STDIN_JSON=""
if [ -z "${PROXY_ACTIVE_MODEL:-}" ] && [ ! -t 0 ]; then
    STDIN_JSON=$(cat 2>/dev/null || echo "")
fi

MODEL_ID="${PROXY_ACTIVE_MODEL:-}" PROXY="$PROXY" \
STDIN_JSON="$STDIN_JSON" CACHE="$CACHE" CATALOG_CACHE="$CATALOG_CACHE" \
CACHE_DIR="$CACHE_DIR" THROTTLE="$THROTTLE" "$PY" - <<'PYEOF'
import json, os, time, calendar, urllib.request

def env(k, d=''):
    return os.environ.get(k, d)

proxy        = env('PROXY').rstrip('/')
cache        = env('CACHE')
catalog_file = env('CATALOG_CACHE')
cache_dir    = env('CACHE_DIR')
throttle     = int(env('THROTTLE', '60'))
model_id     = env('MODEL_ID')
stdin_json   = env('STDIN_JSON')

def load_json(s):
    try: return json.loads(s)
    except Exception: return {}

def fetch(url, timeout=2):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.read().decode('utf-8', 'replace')
    except Exception:
        return ''

def mtime(p):
    try: return os.path.getmtime(p)
    except Exception: return 0

# ── Active model id ────────────────────────────────────────────────────────
if not model_id:
    model_id = load_json(stdin_json).get('model', {}).get('id', '')

# ── Normalized lookup candidates (mirrors llm-proxy buildModelBillingMap) ──
# The proxy advertises BARE deduplicated ids in /v1/models (no backend prefix),
# so a client cannot infer the billing provider from the name. /_/billing.by_model
# is the proxy-authoritative model → billing-provider map; we probe it in
# specificity order: raw id (aliases live here) → claude-/llm-proxy-prefix
# stripped → bare stem (backend-prefixed ids like opencode-go/glm-5.2).
lookup = []
if model_id:
    s = model_id.split('://', 1)[-1].lower()
    s = s.split('[')[0]                         # drop [1m]/[262k] suffix
    if s: lookup.append(s)
    t = s
    for pre in ('llm-proxy/', 'claude-'):
        if t.startswith(pre): t = t[len(pre):]
    if t and t not in lookup: lookup.append(t)  # prefix-stripped
    bare = t.rsplit('/', 1)[-1]
    if bare and bare not in lookup: lookup.append(bare)  # bare stem
model_key = lookup[0] if lookup else ''

# ── Throttle: reuse cache when fresh AND same active model ─────────────────
# Cache keyed on the model id (not a guessed provider), so ANY model switch
# invalidates immediately and re-renders against the new model's provider.
if os.path.exists(cache):
    cached = load_json(open(cache).read() if mtime(cache) else '{}')
    if cached.get('model_key', '') != model_key:
        try: os.remove(cache)   # model changed — show nothing while re-polling
        except Exception: pass
    elif (time.time() - mtime(cache)) < throttle:
        raise SystemExit(0)

os.makedirs(cache_dir, exist_ok=True)
billing = load_json(fetch(proxy + '/_/billing') or '{}')

# ── Resolve provider via /_/billing.by_model (proxy-authoritative) ─────────
provider = ''
by_model = billing.get('by_model') or {}
if isinstance(by_model, dict):
    for k in lookup:
        p = by_model.get(k)
        if p:
            provider = str(p)
            break

# ── Fallback: /v1/models catalog (proxies without by_model) ────────────────
# Older proxies list served ids as "<backend>/<model>"; self-maintaining, no
# hardcoded table. On by_model-capable proxies this adds nothing (bare ids).
stem = lookup[-1] if lookup else ''
if not provider and stem:
    catalog = ''
    if os.path.exists(catalog_file) and (time.time() - mtime(catalog_file)) < 3600:
        try: catalog = open(catalog_file).read()
        except Exception: catalog = ''
    if not catalog:
        catalog = fetch(proxy + '/v1/models')
        if catalog:
            try: open(catalog_file, 'w').write(catalog)
            except Exception: pass
    hit = ''
    for m in load_json(catalog).get('data', []):
        mid = m.get('id', '')
        if '/' not in mid: continue
        prov, name = mid.split('/', 1)
        name = name.split('[')[0]
        if prov.startswith('claude-'): prov = prov[len('claude-'):]  # prefer raw backend
        if name == stem and not hit: hit = prov
    if hit: provider = hit

R='\x1b[0m'; DIM='\x1b[2m'; CY='\x1b[2;36m'; G='\x1b[2;32m'; Y='\x1b[2;33m'; RE='\x1b[2;31m'

def pc(p):
    if p is None: return DIM
    return G if p < 50 else (Y if p < 80 else RE)

def reset_human(epoch):
    if not epoch: return None
    try: diff = float(epoch) - time.time()
    except Exception: return None
    if diff <= 0: return 'now'
    m = int(diff // 60)
    if m < 60: return f'{m}m'
    h = m // 60
    if h < 24: return f'{h}h'
    return f'{h // 24}d'

def reset_from_iso(iso):
    # Parse ISO-8601 UTC as UTC (calendar.timegm), never local time.mktime —
    # a local parse shifts short windows (5h quota) by the host tz offset.
    if not iso: return None
    s = iso.rstrip('Z')
    for fmt in ('%Y-%m-%dT%H:%M:%S.%f', '%Y-%m-%dT%H:%M:%S'):
        try: return calendar.timegm(time.strptime(s, fmt))
        except Exception: pass
    return None

def win_reset(w):
    return w.get('reset_epoch') if w.get('reset_epoch') is not None else reset_from_iso(w.get('reset_at'))

def bar(pct, w=10):
    pct = max(0, min(100, int(round(pct))))
    label = f'{pct}%'
    filled = round(pct / 100 * w)
    pad = max(0, (w - len(label)) // 2)
    fc, ec = '█', '░'
    inner = (fc * filled + ec * (w - filled))
    inner = inner[:pad] + label + inner[pad + len(label):]
    out = []
    for i, ch in enumerate(inner):
        if ch in (fc, ec):
            out.append(f'{pc(pct) if i < filled else DIM}{ch}{R}')
        else:
            out.append(f'{pc(pct)}{ch}{R}')
    return ''.join(out)

PROVIDER_ALIASES = {
    'deepseek':'deepseek', 'glm':'glm', 'kimi':'kimi-code', 'kimi-code':'kimi-code',
    'oai':'openai', 'openai':'openai', 'grok':'grok', 'minimax':'minimax',
}

providers = billing.get('providers', {})
target_key = PROVIDER_ALIASES.get(provider, provider)
target_entry = target_name = None
for name, b in providers.items():
    if name.lower() in (target_key.lower(), provider):
        target_entry, target_name = b, name
        break

segs = []
display_label = ''
stale_mark = ''

if target_entry:
    label = {'kimi-code':'kimi', 'openai':'oai'}.get(target_name, target_name)
    display_label = label
    b = target_entry
    remaining = b.get('remaining'); limit = b.get('limit')
    reset_at = b.get('reset_at'); extra = b.get('extra_credits')
    windows = b.get('windows') or []
    stale_mark = '?' if b.get('stale') else ''

    if limit is None and not windows:                       # credit-only
        bal = remaining if remaining is not None else extra
        if bal is not None: segs.append(f'{G}${bal:.2f}{R}')
    else:
        win_5h = win_mcp = None; win_other = []
        for w in windows:
            wl = (w.get('label') or '').lower()
            if '5h' in wl: win_5h = w
            elif 'mcp' in wl: win_mcp = w
            else: win_other.append(w)

        def pct_of(w):
            p = w.get('usage_pct'); r = w.get('remaining'); l = w.get('limit')
            if p is None and r is not None and l: p = 100 * (l - r) / l
            return p

        if win_5h:                                          # 1. 5h rate window
            p = pct_of(win_5h)
            if p is not None:
                rs = reset_human(win_reset(win_5h))
                segs.append(f'{DIM}5h{R} {bar(p)}' + (f' {DIM}{rs}{R}' if rs else ''))

        if remaining is not None and limit:                 # 2. period/weekly quota
            p = 100 * (limit - remaining) / limit
            ep = b.get('reset_epoch')
            if ep is None: ep = reset_from_iso(reset_at)
            rh = reset_human(ep)
            plabel = rh if (rh and rh.endswith('d')) else (rh or label)
            segs.append(f'{DIM}{plabel}{R} {bar(p)}' + (f' {DIM}{rh}{R}' if rh else ''))

        for w in win_other:                                 # 3. other windows
            p = pct_of(w)
            if p is None: continue
            raw = w.get('label', '')
            wl = raw.replace(' limit','').replace(' tokens','').replace(' calls','')
            if 'in 5d' in raw or '5d' in raw: wl = '5d'
            rs = reset_human(win_reset(w))
            segs.append(f'{DIM}{wl}{R} {bar(p)}' + (f' {DIM}{rs}{R}' if rs else ''))

        if win_mcp:                                         # 4. MCP calls (no bar)
            p = pct_of(win_mcp)
            if p is not None: segs.append(f'{DIM}mcp {pc(p)}{round(p)}%{R}')

        if extra and extra > 0:                             # 5. balance
            segs.append(f'{DIM}{G}${extra:.2f}{R}')

display = f'{DIM}·{R}'.join(segs)
if display and display_label:
    display = f'{CY}{display_label}{stale_mark}{R} {display}'

with open(cache, 'w') as f:
    json.dump({'ts': int(time.time()), 'display': display, 'provider': provider, 'model_key': model_key}, f)
PYEOF
