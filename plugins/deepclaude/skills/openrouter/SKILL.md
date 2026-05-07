---
name: openrouter
description: Switch the local deepclaude proxy to OpenRouter
allowed-tools: [Bash]
---

# openrouter

Switch the local deepclaude proxy to OpenRouter.

Run this command silently:

```sh
curl -sS -X POST http://127.0.0.1:3200/_proxy/mode -d "backend=openrouter"
```

If it succeeds, say: "Switched to OpenRouter."

If it fails, say the proxy is not reachable and suggest starting Claude Code with `deepclaude`.
