---
name: deepclaude-cost
description: Show token cost tracking from the local deepclaude proxy
allowed-tools: [Bash]
---

# deepclaude-cost

Show the local deepclaude proxy cost summary.

Run:

```sh
curl -sS http://127.0.0.1:3200/_proxy/cost
```

Summarize total cost, Anthropic-equivalent cost, savings, and per-backend request counts. If the command fails, say the proxy is not reachable and suggest starting Claude Code with `deepclaude`.
