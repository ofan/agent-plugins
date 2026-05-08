# Model Proxy

Shared local model proxy for `deepclaude`.

## How it works

```
Claude Code instance A ─┐
                        ├─ http://127.0.0.1:3200 ─ session A → DeepSeek
Claude Code instance B ─┘                         └ session B → OpenRouter
```

Each launcher creates a `DEEPCLAUDE_SESSION_ID` and sets it as the local
`ANTHROPIC_AUTH_TOKEN`. The proxy uses that token only for local routing, then
replaces it with the selected provider key before forwarding `/v1/messages`.

## Usage

```javascript
import { startModelProxy } from './model-proxy.js';

const proxy = await startModelProxy({
    targetUrl: 'https://api.deepseek.com/anthropic',
    apiKey: process.env.DEEPSEEK_API_KEY,
});

console.log(`Proxy on port ${proxy.port}`);

// Set env vars for claude remote-control:
// ANTHROPIC_BASE_URL=http://127.0.0.1:${proxy.port}
// ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro
// ANTHROPIC_AUTH_TOKEN=dcx_<session-id>

// When done:
proxy.close();
```

## Control API

```sh
curl -sS http://127.0.0.1:3200/_proxy/status
curl -sS "http://127.0.0.1:3200/_proxy/status?session=$DEEPCLAUDE_SESSION_ID"
curl -sS -X POST http://127.0.0.1:3200/_proxy/mode \
  -d "backend=deepseek&session=$DEEPCLAUDE_SESSION_ID"
```

Without a `session`, `/mode` changes the default backend for new sessions.
