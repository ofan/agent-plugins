# deepclaude v2: Full Claude Wrapper + Codex Backend

## Goal

`claude` transparently runs through deepclaude. The proxy handles API translation.
Add OpenAI/Codex as a backend.

## Architecture

```
~/bin/claude → deepclaude (symlink)
~/bin/deepclaude → same script

deepclaude script:
  ├── detect $0 → "claude" or "deepclaude"
  ├── claude mode: no flag interception, transparent passthrough
  ├── deepclaude mode: intercept --status/--cost/--switch/--backend/--help/--benchmark
  ├── resolve_backend() → single source of truth for models, URLs, keys
  ├── launch() → start/reuse proxy → heartbeat → clean PATH → exec real claude
  └── find real claude by stripping own dir from PATH

proxy/:
  ├── start-proxy.js       (unchanged)
  ├── model-proxy.js       (add codex backend + routing)
  └── translate-openai.js  (NEW: Anthropic ↔ OpenAI format translation)
```

## Invocation modes

| Invoked as | Flags intercepted | Default backend |
|---|---|---|
| `claude` | None — all args pass through | `DEEPCLAUDE_DEFAULT_BACKEND` (default: deepseek) |
| `deepclaude` | `--backend`, `--status`, `--cost`, `--switch`, `--help`, `--benchmark` | deepseek |

## Finding real claude

Strip script's own directory from `$PATH`, then `exec claude`. This avoids self-recursion when `~/bin/claude` is a symlink to the script.

```sh
clean_path() {
    local exclude="$1" result="" saved_IFS="$IFS"
    IFS=:
    for p in $PATH; do
        [ "$p" = "$exclude" ] && continue
        result="${result:+$result:}$p"
    done
    IFS="$saved_IFS"
    echo "$result"
}
```

## Backend config (resolve_backend)

| Backend | Env var | URL | Opus model | Sonnet model | Haiku model | Subagent model |
|---|---|---|---|---|---|---|
| deepseek | DEEPSEEK_API_KEY | api.deepseek.com/anthropic | deepseek-v4-pro[1m] | deepseek-v4-pro[1m] | deepseek-v4-flash[1m] | deepseek-v4-flash[1m] |
| openrouter | OPENROUTER_API_KEY | openrouter.ai/api/v1 | deepseek/deepseek-v4-pro[1m] | deepseek/deepseek-v4-pro[1m] | deepseek/deepseek-v4-pro[1m] | deepseek/deepseek-v4-pro[1m] |
| codex | OPENAI_API_KEY | api.openai.com/v1 | gpt-5.5[1m] | gpt-5.4[1m] | gpt-5.4[1m] | gpt-5.4[1m] |
| anthropic | (none) | api.anthropic.com | (unset) | (unset) | (unset) | (unset) |

Shortcuts: `-b ds` (deepseek), `-b or` (openrouter), `-b cx` (codex), `-b anthropic`.

## Proxy: Codex backend routing

Anthropic's protocol is a superset of OpenAI's. Translation in the Anthropic→OpenAI direction is lossy (thinking blocks, cache breakpoints, structured system prompts, tool_result blocks). DeepSeek and OpenRouter already speak Anthropic natively. So:

**Request side: minimal.** Only remap model name and swap auth header. Pass the Anthropic request body through as-is — OpenAI's `/v1/chat/completions` handles most of it directly since Claude Code sends standard JSON. Fields like `messages`, `max_tokens`, `temperature`, `stream`, `tools`, `stop_sequences` are compatible enough.

**Response side: full translation.** Reconstruct Anthropic's rich SSE event structure from OpenAI's flat delta stream. This is the real work.

New file `proxy/translate-openai.js`:

**`mapCodexRequest(req)`** — thin wrapper
- Remap model via MODEL_REMAP
- Swap `x-api-key` → `Authorization: Bearer`
- Return `{ url, headers, body }` (body unchanged)

**`CodexResponseSSE`** — Transform-like class
- Ingests OpenAI SSE chunks (`data: {...}` lines)
- Reconstructs Anthropic's block-structured events:
  - First content chunk → `message_start` (with model+[1m], usage placeholder)
  - Text delta → `content_block_delta` (type: `text_delta`)
  - Tool call name → `content_block_start` (type: `tool_use`, with id/name/empty input)
  - Tool call args → `content_block_delta` (type: `input_json_delta`)
  - `finish_reason` → `message_delta` (with `stop_reason` + `usage`)
  - `[DONE]` → `message_stop`
- Tracks content block indices and open tool call state
- Preserves Anthropic's invariant: `content_block_start` always precedes `content_block_delta` for each block

**model-proxy.js changes:**
- Add `codex` to `MODEL_REMAP` and `BACKEND_DEFS`
- When backend is `codex`: pipe request through `mapCodexRequest`, pipe response through `CodexResponseSSE` before `UsageNormalizer`

## Model remapping (proxy)

```js
codex: {
    'claude-opus-4-7':             'gpt-5.5',
    'claude-opus-4-6':             'gpt-5.5',
    'claude-sonnet-4-6':           'gpt-5.4',
    'claude-sonnet-4-5-20250929':  'gpt-5.4',
    'claude-haiku-4-5-20251001':   'gpt-5.4',
}
```

## Files changed

| File | Change |
|---|---|
| `deepclaude` | Add codex backend, PATH cleaning, $0 detection, transparent mode |
| `proxy/model-proxy.js` | Add codex backend routing + format translation hook |
| `proxy/translate-openai.js` | **NEW** — Anthropic ↔ OpenAI format translation |
| `install.sh` | Add `~/bin/claude` symlink |

## Verification

1. `claude --help` → shows real claude help (no recursion)
2. `claude --model sonnet -p "hello"` → routes through deepseek proxy, returns response
3. `deepclaude --status` → shows all 4 backends, proxy info
4. `deepclaude -b cx` → launches Claude Code via Codex/OpenAI, model names set correctly
5. `deepclaude -b cx --switch or` → live switch from codex to openrouter
6. `claude -p "test"` with `DEEPCLAUDE_DEFAULT_BACKEND=codex` → uses codex backend
