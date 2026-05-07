---
name: anthropic
description: Switch the local deepclaude proxy to Anthropic
allowed-tools: [Bash]
---

# anthropic

Switch the local deepclaude proxy back to Anthropic.

Run this command silently:

```sh
curl -sS -X POST http://127.0.0.1:3200/_proxy/mode -d "backend=anthropic"
```

If it succeeds, say: "Switched to Anthropic."

If it fails, say the proxy is not reachable and suggest starting Claude Code with `deepclaude`.
