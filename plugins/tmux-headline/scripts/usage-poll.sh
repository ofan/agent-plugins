#!/usr/bin/env bash
# Poll Claude API for subscription usage (5h/7d limits)
# Sends a minimal Haiku request to read rate limit headers
# Writes results to ~/.claude/headline/usage.json
# Supports both file-based credentials and macOS keychain
set -f

USAGE_FILE="$HOME/.claude/headline/usage.json"

python3 << 'PYEOF'
import json, os, platform, subprocess, sys, time
try:
    from urllib.request import Request, urlopen
except ImportError:
    sys.exit(0)

usage_file = os.path.expanduser("~/.claude/headline/usage.json")

# Skip if polled recently (< 60s)
try:
    if os.path.exists(usage_file):
        age = time.time() - os.path.getmtime(usage_file)
        if age < 60:
            sys.exit(0)
except:
    pass

token = None

# Try file-based credentials first (Linux, older Claude Code)
creds_file = os.path.expanduser("~/.claude/.credentials.json")
if os.path.exists(creds_file):
    try:
        with open(creds_file) as f:
            creds = json.load(f)
        oauth = creds.get("claudeAiOauth", {})
        if oauth.get("expiresAt", 0) / 1000 > time.time():
            token = oauth.get("accessToken")
    except:
        pass

# Fall back to macOS keychain (current Claude Code on macOS)
if not token and platform.system() == "Darwin":
    try:
        raw = subprocess.check_output(
            ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            stderr=subprocess.DEVNULL, timeout=5
        ).decode().strip()
        creds = json.loads(raw)
        oauth = creds.get("claudeAiOauth", {})
        if oauth.get("expiresAt", 0) / 1000 > time.time():
            token = oauth.get("accessToken")
    except:
        pass

if not token:
    sys.exit(0)

# Minimal Haiku call — costs ~9 tokens
body = json.dumps({
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 1,
    "messages": [{"role": "user", "content": "x"}]
}).encode()

req = Request("https://api.anthropic.com/v1/messages", data=body, method="POST")
req.add_header("Authorization", f"Bearer {token}")
req.add_header("Content-Type", "application/json")
req.add_header("anthropic-version", "2023-06-01")
req.add_header("anthropic-beta", "oauth-2025-04-20")

try:
    resp = urlopen(req, timeout=5)
    headers = {k.lower(): v for k, v in resp.headers.items()}

    usage = {
        "ts": int(time.time()),
        "5h": float(headers.get("anthropic-ratelimit-unified-5h-utilization", "0")),
        "5h_reset": int(headers.get("anthropic-ratelimit-unified-5h-reset", "0")),
        "7d": float(headers.get("anthropic-ratelimit-unified-7d-utilization", "0")),
        "7d_reset": int(headers.get("anthropic-ratelimit-unified-7d-reset", "0")),
        "status": headers.get("anthropic-ratelimit-unified-status", "unknown"),
    }

    os.makedirs(os.path.dirname(usage_file), exist_ok=True)
    with open(usage_file + ".tmp", "w") as f:
        json.dump(usage, f)
    os.rename(usage_file + ".tmp", usage_file)
except Exception as e:
    pass
PYEOF
