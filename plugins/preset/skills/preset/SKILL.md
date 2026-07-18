---
name: preset
description: Switch the active preset backend for the current session on the llm-proxy (scoped HMAC). Usage /preset <backend|off>
allowed-tools: [Bash]
---

# preset

Switch the active preset backend for the current session on the llm-proxy.
The argument `$1` is the backend name (e.g. `glm`, `deepseek`, `minimax`) or
`off` to disable the preset for this session (passthrough).

## Prerequisites

- `$ANTHROPIC_BASE_URL` — the proxy base URL (already set in the Claude Code env
  when running through the proxy).
- `$PROXY_PRESET_SECRET` — the shared HMAC secret. If unset, tell the user to
  set it in their environment (it must match the proxy's `PROXY_PRESET_SECRET`).
- `$CLAUDE_CODE_SESSION_ID` — the current session id (set by Claude Code).

The proxy mints the expected token as
`preset_<HMAC-SHA256(key=$PROXY_PRESET_SECRET, message=$CLAUDE_CODE_SESSION_ID)>`
and this skill computes the same token client-side (key=secret, message=session).

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
  echo "Usage: /preset <backend|off>"
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

- On success (HTTP 200): say "Switched to <backend>."
- On failure (non-200, curl error, or unset secret): report the HTTP code +
  response body verbatim so the user can diagnose. Do not claim success.
