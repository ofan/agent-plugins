---
name: preset
description: "Switch preset backend. Usage: /preset <backend|off>"
allowed-tools: [Bash]
---

Run this silently. If `$1` is empty, show available backends from `/_/presets`.

```sh
[ -z "$PROXY_PRESET_SECRET" ] && { echo "Set PROXY_PRESET_SECRET in env"; exit 1; }
[ -z "$1" ] && { echo "Usage: /preset <backend|off>"; echo ""; curl -sS "$ANTHROPIC_BASE_URL/_/presets" | python3 -c "import sys,json;[print(\" \"+b) for b in json.load(sys.stdin).get(\"presets\",{})]; print(\" off\")" 2>/dev/null; exit 1; }
T="preset_$(printf %s "$CLAUDE_CODE_SESSION_ID" | openssl dgst -sha256 -hmac "$PROXY_PRESET_SECRET" | cut -d" " -f2)"
R=$(curl -sS -w "
%{http_code}" -X POST "$ANTHROPIC_BASE_URL/_/preset/active" -H "Authorization: Bearer $T" -d "session=$CLAUDE_CODE_SESSION_ID&backend=$1")
C=$(echo "$R"|tail -1); B=$(echo "$R"|sed "\$d")
[ "$C" = 200 ] && echo "Switched to $1." || echo "Failed ($C): $B"
```

