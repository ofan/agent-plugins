#!/bin/sh
# Claude Code statusLine: renders the tmux-headline base line, then appends
# effort + the ACTIVE model's proxy billing/limits.
#
# This is the proxy-aware wrapper around statusline.js. Wire it as:
#   "statusLine": { "type": "command",
#     "command": "bash ~/.claude/plugins/marketplaces/ofan-plugins/plugins/tmux-headline/scripts/statusline-effort.sh" }
#
# Effort source: CLAUDE_EFFORT env (set by /effort), else the statusLine input
# JSON "effort" field.
#
# Proxy billing: polls /_/billing for the ACTIVE model's provider via the
# sibling proxy-cost-poll.sh. HEADLINE_PROXY_ONLY=1 suppresses the plugin's
# built-in Anthropic plan/cost segments (they read Anthropic rate-limit headers
# that are meaningless when ANTHROPIC_BASE_URL routes through llm-proxy).
#
# Cross-platform: POSIX sh + Node + python3; works on Linux, macOS, Git Bash,
# WSL. PLUGIN_DIR resolves the script's own location so the poll script is
# found regardless of where the repo is checked out.
input=$(cat)

# Resolve this script's directory (works invoked via bash/sh, abs or ~ path).
PLUGIN_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
[ -z "$PLUGIN_DIR" ] && PLUGIN_DIR="$HOME/.claude/plugins/marketplaces/ofan-plugins/plugins/tmux-headline/scripts"
ROOT_DIR=$(dirname "$PLUGIN_DIR")

# Render base line with proxy-only suppression.
base=$(printf '%s' "$input" | env HEADLINE_PROXY_ONLY=1 node "$ROOT_DIR/statusline.js" 2>/dev/null | tr -d '\r\n')

# Resolve effort.
effort="${CLAUDE_EFFORT:-}"
if [ -z "$effort" ]; then
  effort=$(printf '%s' "$input" | sed -n 's/.*"effort"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi

# Poll proxy billing for the active model (throttled internally). Feed the
# statusline JSON so the poll can read .model.id. Non-fatal if it errors.
printf '%s' "$input" | bash "$PLUGIN_DIR/proxy-cost-poll.sh" 2>/dev/null || true

# Read cached display.
proxy_cost=""
CACHE="$HOME/.cache/tmux-headline/proxy-cost.json"
if [ -f "$CACHE" ]; then
  PY="$(command -v python3 || command -v python || true)"
  # The cache path below is baked into the python -c source, so it survives
  # inside the interpreter verbatim — the MSYS shell only translates paths on
  # the command line of a native Windows program, not inside -c strings. When
  # python is a native Windows build (py launcher / AppData python.exe), the
  # POSIX $HOME form (/c/Users/... or /home/...) won't resolve, so translate
  # to a Windows path first. cygpath is a no-op-safe fallback everywhere else.
  CACHE_PY="$CACHE"
  command -v cygpath >/dev/null 2>&1 && CACHE_PY="$(cygpath -m "$CACHE" 2>/dev/null || printf '%s' "$CACHE")"
  # PYTHONIOENCODING=utf-8: on Windows, native python defaults stdout to the
  # console codepage (cp1252), which cannot encode the ▀/░ block glyphs the
  # billing bars use — print() then throws UnicodeEncodeError and the second
  # line silently vanishes (only ASCII displays like a bare $balance survive).
  # Forcing UTF-8 keeps the glyphs intact; harmless on Linux/macOS.
  [ -n "$PY" ] && proxy_cost=$(PYTHONIOENCODING=utf-8 "$PY" -c "import json;print(json.load(open('$CACHE_PY')).get('display',''))" 2>/dev/null || true)
fi

# Assemble. Row 1: base + effort. Row 2: active-model limit/usage (if any).
sep=$(printf '\033[2m \302\267 \033[0m')
out="$base"
if [ -n "$effort" ]; then
  out="$out${sep}$(printf '\033[2;33m')effort:$effort$(printf '\033[0m')"
fi
printf '%s\n' "$out"
if [ -n "$proxy_cost" ]; then
  printf '%s\n' "$proxy_cost"
fi
