# deepclaude v2: Full Claude Wrapper + Codex Backend

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** `claude` runs transparently through deepclaude proxy; add OpenAI/Codex backend.

**Architecture:** Single shell script detects invocation name (`claude` vs `deepclaude`) via `$0`. Claude mode passes all args through; deepclaude mode intercepts management flags. PATH cleaning prevents self-recursion. New `translate-openai.js` module handles Anthropic ↔ OpenAI format conversion in the proxy.

**Tech Stack:** Bash, Node.js (ESM), OpenAI API

---

### Task 1: Refactor deepclaude arg parsing for full passthrough

**Files:**
- Modify: `~/projects/agent-plugins/plugins/deepclaude/deepclaude` — arg loop and invocation detection

- [ ] **Step 1: Detect invocation name from `$0`**

Replace the top-level arg parsing logic. After the config section (line 15), before the command functions, add invocation detection:

```sh
# Detect how we were invoked
INVOKED_AS="$(basename "$0")"

# If called as "claude", transparent mode: no flag interception
if [ "$INVOKED_AS" = "claude" ]; then
    BACKEND="${DEEPCLAUDE_DEFAULT_BACKEND:-deepseek}"
    resolve_backend
    launch "$@"
fi
```

- [ ] **Step 2: Fix arg loop so unknown flags pass through**

Replace the current `while` arg loop (lines 291-331). All unknown flags should be collected and forwarded:

```sh
BACKEND="${DEEPCLAUDE_DEFAULT_BACKEND:-deepseek}"
ACTION="launch"
SWITCH_BACKEND=""
PASSTHROUGH_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --status)       ACTION="status"; shift ;;
        --cost)         ACTION="cost"; shift ;;
        --benchmark)    ACTION="benchmark"; shift ;;
        --help|-h)      ACTION="help"; shift ;;
        --switch|-s)    ACTION="switch"; SWITCH_BACKEND="$2"; shift 2 ;;
        --backend|-b)
            case "$2" in
                ds|deepseek)   BACKEND="deepseek" ;;
                or|openrouter) BACKEND="openrouter" ;;
                cx|codex)      BACKEND="codex" ;;
                anthropic)     BACKEND="anthropic" ;;
                *) echo "deepclaude: unknown backend '$2'" >&2; exit 2 ;;
            esac
            shift 2
            ;;
        *)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
    esac
done

# Passthrough args become positional for claude
set -- "${PASSTHROUGH_ARGS[@]}"
```

This drops the `--` separator requirement — any unknown flag flows through.

- [ ] **Step 3: Verify syntax**

Run: `bash -n ~/projects/agent-plugins/plugins/deepclaude/deepclaude`
Expected: no output (syntax OK)

- [ ] **Step 4: Test arg passthrough**

Run: `deepclaude --model sonnet --status 2>&1`
Expected: shows status (intercepts `--status`), ignores `--model`

Run: `deepclaude --model sonnet -p "echo hi" 2>&1 | head -5`
Expected: proxy starts, launches claude with `--model sonnet -p "echo hi"`

### Task 2: Add PATH cleaning to find real claude

**Files:**
- Modify: `~/projects/agent-plugins/plugins/deepclaude/deepclaude` — `launch()` and `clean_path()`

- [ ] **Step 1: Add `clean_path()` function**

After `mask_key()` (after line 21), add:

```sh
clean_path() {
    local exclude="$1" result="" saved_IFS="$IFS"
    IFS=:
    for p in $PATH; do
        [ "$p" = "$exclude" ] && continue
        [ -z "$p" ] && continue
        result="${result:+$result:}$p"
    done
    IFS="$saved_IFS"
    echo "$result"
}
```

- [ ] **Step 2: Use cleaned PATH in `launch()`**

In the `launch()` function, replace both `exec claude "$@"` calls (lines 210 and 271) with:

```sh
CLEANED_PATH="$(clean_path "$SCRIPT_DIR")"
PATH="$CLEANED_PATH" exec claude "$@"
```

This strips the script's own directory from PATH before calling claude, preventing self-recursion.

- [ ] **Step 3: Verify syntax**

Run: `bash -n ~/projects/agent-plugins/plugins/deepclaude/deepclaude`
Expected: no output

### Task 3: Add codex backend to resolve_backend and show_* commands

**Files:**
- Modify: `~/projects/agent-plugins/plugins/deepclaude/deepclaude` — `resolve_backend()`, `show_status()`, `show_cost()`, `show_help()`, `do_switch()`, `run_benchmark()`

- [ ] **Step 1: Add codex case to `resolve_backend()`**

After the `anthropic)` case (after line 51), add:

```sh
        codex)
            [ -n "${OPENAI_API_KEY:-}" ] || { echo "deepclaude: OPENAI_API_KEY is not set" >&2; exit 1; }
            TARGET_URL="https://api.openai.com/v1"
            TARGET_KEY="$OPENAI_API_KEY"
            OPUS_MODEL="gpt-5.5[1m]"
            SONNET_MODEL="gpt-5.4[1m]"
            HAIKU_MODEL="gpt-5.4[1m]"
            SUBAGENT_MODEL="gpt-5.4[1m]"
            ;;
```

- [ ] **Step 2: Update `show_status()`**

Add codex to the backends list (after line 101):

```sh
    echo "    deepclaude -b cx            # OpenAI Codex (GPT-5.5/GPT-5.4)"
```

And add key display:

```sh
    echo "    OPENAI_API_KEY:       $(mask_key "${OPENAI_API_KEY:-}")"
```

- [ ] **Step 3: Update `show_cost()`**

Add codex pricing row (after line 123):

```sh
    echo "  Codex (GPT-5)   \$5.00     \$30.00    (standard)"
```

- [ ] **Step 4: Update `show_help()`**

Add `cx|codex` to the backend help line (line 133).

- [ ] **Step 5: Update `do_switch()`**

Add `cx|codex) backend="codex" ;;` to the case statement (after line 151).

- [ ] **Step 6: Add codex to `run_benchmark()`**

After the openrouter case (after line 178), add:

```sh
            codex)
                url="https://api.openai.com/v1"
                key="${OPENAI_API_KEY:-}"
                model="gpt-5.4"
                ;;
```

And add `codex` to the `for name in` loop (line 166): `for name in deepseek openrouter codex; do`

The benchmark curl needs different auth header for codex. After the openrouter curl, add a conditional:

```sh
        local auth_header="x-api-key: $key"
        [ "$name" = "codex" ] && auth_header="Authorization: Bearer $key"
```

- [ ] **Step 7: Verify syntax**

Run: `bash -n ~/projects/agent-plugins/plugins/deepclaude/deepclaude`
Expected: no output

- [ ] **Step 8: Test `--status`**

Run: `deepclaude --status`
Expected: shows 4 backends (deepseek, openrouter, codex, anthropic) and OPENAI_API_KEY status

### Task 4: Update install.sh with claude symlink

**Files:**
- Modify: `~/projects/agent-plugins/plugins/deepclaude/install.sh`

- [ ] **Step 1: Add `~/bin/claude` symlink**

After the deepclaude symlink line in install.sh, add:

```sh
# Also symlink as claude (transparent wrapper)
ln -sf "$INSTALL_ROOT/deepclaude" "$HOME/bin/claude" 2>/dev/null || \
    echo "Warning: could not symlink to ~/bin/claude" >&2
```

- [ ] **Step 2: Test install**

Run: `cd ~/projects/agent-plugins/plugins/deepclaude && bash install.sh`
Expected: creates `~/bin/claude` → `~/.local/share/deepclaude/deepclaude`

### Task 5: Create translate-openai.js module

**Files:**
- Create: `~/projects/agent-plugins/plugins/deepclaude/proxy/translate-openai.js`

- [ ] **Step 1: Write the Anthropic-to-OpenAI request translator**

```js
// translate-openai.js — Anthropic ↔ OpenAI API format translation

const MODEL_REMAP = {
    'claude-opus-4-7':             'gpt-5.5',
    'claude-opus-4-6':             'gpt-5.5',
    'claude-sonnet-4-6':           'gpt-5.4',
    'claude-sonnet-4-5-20250929':  'gpt-5.4',
    'claude-haiku-4-5-20251001':   'gpt-5.4',
};

export function anthropicToOpenAI(anthropicReq) {
    const body = JSON.parse(anthropicReq.body);

    // Build messages array
    const messages = [];
    if (body.system) {
        const systemContent = Array.isArray(body.system)
            ? body.system.map(b => b.text || b.content).join('\n')
            : body.system;
        messages.push({ role: 'system', content: systemContent });
    }
    for (const msg of (body.messages || [])) {
        messages.push({ role: msg.role, content: msg.content });
    }

    // Build OpenAI request
    const openaiBody = {
        model: MODEL_REMAP[body.model] || body.model,
        messages,
        stream: body.stream || false,
    };
    if (body.max_tokens) openaiBody.max_tokens = body.max_tokens;
    if (body.temperature != null) openaiBody.temperature = body.temperature;
    if (body.stop_sequences) openaiBody.stop = body.stop_sequences;

    // Convert tools
    if (body.tools && body.tools.length > 0) {
        openaiBody.tools = body.tools.map(t => ({
            type: 'function',
            function: {
                name: t.name,
                description: t.description,
                parameters: t.input_schema,
            },
        }));
        // OpenAI doesn't support tool_choice "any" — map to "auto"
        if (body.tool_choice) {
            openaiBody.tool_choice = body.tool_choice.type === 'any' ? 'auto' : 'auto';
        }
    }

    return {
        url: new URL('/v1/chat/completions', anthropicReq.url),
        headers: {
            'Authorization': `Bearer ${anthropicReq.headers.get('x-api-key') || ''}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(openaiBody),
    };
}
```

- [ ] **Step 2: Write the OpenAI-SSE-to-Anthropic-SSE response translator**

```js
export class OpenAIToAnthropicSSE {
    constructor() {
        this._buf = '';
        this._started = false;
        this._contentIndex = 0;
        this._toolIndex = 0;
        this._inputTokens = 0;
        this._outputTokens = 0;
        this._model = '';
        this._stopReason = 'end_turn';
    }

    _emit(type, data) {
        return `data: ${JSON.stringify({ type, ...data })}\n\n`;
    }

    ingest(chunk) {
        this._buf += chunk.toString();
        const parts = this._buf.split('\n\n');
        this._buf = parts.pop();
        const results = [];
        for (const part of parts) {
            const lines = part.split('\n');
            for (const line of lines) {
                if (!line.startsWith('data: ')) continue;
                if (line === 'data: [DONE]') {
                    results.push(this._emit('message_stop', {}));
                    continue;
                }
                try {
                    const d = JSON.parse(line.slice(6));
                    const converted = this._convert(d);
                    if (converted) results.push(converted);
                } catch (_) { /* skip malformed */ }
            }
        }
        return results.join('');
    }

    _convert(d) {
        if (!d.choices || !d.choices[0]) return null;
        const choice = d.choices[0];
        const delta = choice.delta || {};

        // Capture model from first chunk
        if (d.model) this._model = d.model;

        // First content chunk → message_start
        if (!this._started && (delta.content || delta.tool_calls)) {
            this._started = true;
            return this._emit('message_start', {
                message: {
                    id: d.id || 'msg_1',
                    type: 'message',
                    role: 'assistant',
                    model: this._model + '[1m]',
                    content: [],
                    usage: { input_tokens: 0, output_tokens: 0 },
                },
            });
        }

        // Text content delta
        if (delta.content) {
            return this._emit('content_block_delta', {
                index: this._contentIndex,
                delta: { type: 'text_delta', text: delta.content },
            });
        }

        // Tool call delta
        if (delta.tool_calls) {
            for (const tc of delta.tool_calls) {
                if (tc.function?.name) {
                    // New tool call starts
                    return this._emit('content_block_start', {
                        index: this._toolIndex,
                        content_block: {
                            type: 'tool_use',
                            id: tc.id || `toolu_${this._toolIndex}`,
                            name: tc.function.name,
                            input: {},
                        },
                    });
                }
                if (tc.function?.arguments) {
                    return this._emit('content_block_delta', {
                        index: this._toolIndex,
                        delta: {
                            type: 'input_json_delta',
                            partial_json: tc.function.arguments,
                        },
                    });
                }
            }
        }

        // Finish → message_delta
        if (choice.finish_reason) {
            // Capture usage from last chunk
            if (d.usage) {
                this._outputTokens = d.usage.completion_tokens || 0;
                this._inputTokens = d.usage.prompt_tokens || 0;
            }
            const stopMap = { 'stop': 'end_turn', 'tool_calls': 'tool_use', 'length': 'max_tokens' };
            const stopReason = stopMap[choice.finish_reason] || choice.finish_reason;
            return this._emit('message_delta', {
                delta: { stop_reason: stopReason },
                usage: { output_tokens: this._outputTokens },
            });
        }

        return null;
    }
}
```

- [ ] **Step 3: Verify module loads**

Run: `node -e "import('./proxy/translate-openai.js').then(m => console.log(Object.keys(m)))"` from the plugin dir
Expected: `[ 'anthropicToOpenAI', 'OpenAIToAnthropicSSE' ]`

### Task 6: Integrate codex backend into model-proxy.js

**Files:**
- Modify: `~/projects/agent-plugins/plugins/deepclaude/proxy/model-proxy.js`

- [ ] **Step 1: Import translate-openai**

Add at the top of model-proxy.js (after line 4):

```js
import { anthropicToOpenAI, OpenAIToAnthropicSSE } from './translate-openai.js';
```

- [ ] **Step 2: Add codex to MODEL_REMAP**

After the openrouter block in MODEL_REMAP (after line 26), add:

```js
    codex: {
        'claude-opus-4-7':             'gpt-5.5',
        'claude-opus-4-6':             'gpt-5.5',
        'claude-sonnet-4-6':           'gpt-5.4',
        'claude-sonnet-4-5-20250929':  'gpt-5.4',
        'claude-haiku-4-5-20251001':   'gpt-5.4',
    },
```

- [ ] **Step 3: Add codex to BACKEND_DEFS in start-proxy.js**

In `start-proxy.js`, add after the openrouter entry:

```js
    codex: { url: 'https://api.openai.com/v1', keyEnv: 'OPENAI_API_KEY' },
```

- [ ] **Step 4: Route codex requests through translation**

In `model-proxy.js`, find the request handler where the backend is resolved and add translation routing. After the MODEL_REMAP lookup, before the request is sent:

```js
const isCodex = activeBackend === 'codex';
if (isCodex) {
    const translated = anthropicToOpenAI({ url: targetUrl, headers: reqHeaders, body: rawBody });
    targetUrl = translated.url;
    reqHeaders = new Headers(translated.headers);
    rawBody = translated.body;
}
```

And on the SSE response path, pipe through `OpenAIToAnthropicSSE` before `UsageNormalizer`:

```js
const openaiSSE = isCodex ? new OpenAIToAnthropicSSE() : null;
// ... in the response handler:
if (openaiSSE) {
    const anthropicEvents = openaiSSE.ingest(chunk);
    // feed anthropicEvents through the UsageNormalizer
}
```

- [ ] **Step 5: Verify syntax**

Run: `node --check ~/projects/agent-plugins/plugins/deepclaude/proxy/model-proxy.js`
Expected: no output

### Task 7: Sync and end-to-end verify

- [ ] **Step 1: Sync to cache and install location**

```sh
cp ~/projects/agent-plugins/plugins/deepclaude/deepclaude ~/.claude/plugins/cache/ofan-plugins/deepclaude/0.2.3/deepclaude
cp ~/projects/agent-plugins/plugins/deepclaude/proxy/translate-openai.js ~/.claude/plugins/cache/ofan-plugins/deepclaude/0.2.3/proxy/
cp ~/projects/agent-plugins/plugins/deepclaude/proxy/model-proxy.js ~/.claude/plugins/cache/ofan-plugins/deepclaude/0.2.3/proxy/
cp ~/projects/agent-plugins/plugins/deepclaude/proxy/start-proxy.js ~/.claude/plugins/cache/ofan-plugins/deepclaude/0.2.3/proxy/
bash ~/projects/agent-plugins/plugins/deepclaude/install.sh
```

- [ ] **Step 2: Test `claude --help` doesn't recurse**

Run: `~/bin/claude --help 2>&1 | head -5`
Expected: shows real Claude Code help, NOT deepclaude help, no recursion loop

- [ ] **Step 3: Test `deepclaude --status` with new backends**

Run: `deepclaude --status`
Expected: shows codex backend and OPENAI_API_KEY status

- [ ] **Step 4: Test arg passthrough**

Run: `deepclaude --model sonnet --print "hello" 2>&1 | head -10`
Expected: proxy starts in deepseek mode, claude runs with --model sonnet -p "hello"

- [ ] **Step 5: Kill proxy to test fresh start**

```sh
kill $(pgrep -f "start-proxy.js") 2>/dev/null; sleep 1
deepclaude --cost
```
Expected: proxy starts fresh, shows pricing with codex row

- [ ] **Step 6: Test `deepclaude -b cx`**

Run: `OPENAI_API_KEY=sk-test deepclaude -b cx --status`
Expected: shows codex as active backend

- [ ] **Step 7: Verify no double `[1m]`**

Run: `deepclaude --status 2>&1 | grep '1m'`
Expected: each model shows `[1m]` exactly once
