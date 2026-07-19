---
name: preset
description: "Switch the active preset backend for this session on the llm-proxy (scoped HMAC). Usage /preset <backend|off>."
allowed-tools: [Bash]
---

# Preset

Switch the active preset backend for the current session on the llm-proxy.
The argument `$1` is a backend that has tier presets configured (see
`/_/presets` for the list), or `off` to disable the preset for this session.

## Run this silently

```sh
if [ -z "$PROXY_PRESET_SECRET" ]; then
  echo "PROXY_PRESET_SECRET is not set — set it in your environment (must match the proxy's secret)."
  exit 1
fi
if [ -z "$ANTHROPIC_BASE_URL" ]; then
  echo "ANTHROPIC_BASE_URL is not set — are you running through the proxy?"
  exit 1
fi
if [ -z "$CLAUDE_CODE_SESSION_ID" ]; then
  echo "CLAUDE_CODE_SESSION_ID is not set — run /preset inside a Claude Code session."
  exit 1
fi
if [ -z "$1" ]; then
  echo "No backend argument provided. Usage: /preset <backend|off>"
  echo ""
  echo "Available preset backends (from /_/presets):"
  curl -sS "$ANTHROPIC_BASE_URL/_/presets" | python3 -c "import sys,json;d=json.load(sys.stdin);[print('  '+b) for b in d.get('presets',{}).keys()]; print('  off (passthrough)')" 2>/dev/null
  exit 1
fi
T="preset_$(printf %s "$CLAUDE_CODE_SESSION_ID" \
  | openssl dgst -sha256 -hmac "$PROXY_PRESET_SECRET" | cut -d" " -f2)"
RESP=$(curl -sS -w "\n%{http_code}" -X POST "$ANTHROPIC_BASE_URL/_/preset/active" \
  -H "Authorization: Bearer $T" \
  -d "session=$CLAUDE_CODE_SESSION_ID&backend=$1")
CODE=$(echo "$RESP" | tail -n1)
BODY=$(echo "$RESP" | sed '$d')
if [ "$CODE" = "200" ]; then
  echo "Switched to $1."
else
  echo "Switch failed (HTTP $CODE): $BODY"
fi
```

## Reporting

- On success (HTTP 200): say "Switched to $1."
- On failure (non-200, curl error, or unset secret): report the HTTP code + response body verbatim so the user can diagnose. Do not claim success.
