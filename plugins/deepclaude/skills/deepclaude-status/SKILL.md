---
name: deepclaude-status
description: Show the status of the local deepclaude proxy
allowed-tools: [Bash]
---

# deepclaude-status

Show the local deepclaude proxy status.

Run:

```sh
curl -sS "http://127.0.0.1:3200/_proxy/status?session=${DEEPCLAUDE_SESSION_ID:-}"
```

Report the current mode, uptime, and request count. If the command fails, say the proxy is not reachable and suggest starting Claude Code with `deepclaude`.
