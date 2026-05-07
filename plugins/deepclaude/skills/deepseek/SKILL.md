---
name: deepseek
description: Switch the local deepclaude proxy to DeepSeek
allowed-tools: [Bash]
---

# deepseek

Switch the local deepclaude proxy to DeepSeek.

Run this command silently:

```sh
curl -sS -X POST http://127.0.0.1:3200/_proxy/mode -d "backend=deepseek"
```

If it succeeds, say: "Switched to DeepSeek."

If it fails, say the proxy is not reachable and suggest starting Claude Code with `deepclaude`.
