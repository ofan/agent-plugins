import { createServer } from 'http';
import { request as httpsRequest } from 'https';
import { URL } from 'url';
import { Transform } from 'stream';
import { mapCodexRequest, CodexResponseSSE } from './translate-openai.js';

const ANTHROPIC_FALLBACK = 'https://api.anthropic.com';
const MODEL_PATHS = ['/v1/messages'];
const REQUEST_TIMEOUT_MS = 5 * 60 * 1000; // 5 min per request
const DEFAULT_IDLE_TTL_MS = 30 * 60 * 1000; // 30 min after no live sessions
const DEFAULT_SESSION_TTL_MS = 12 * 60 * 60 * 1000; // stale fallback when no pid is known

const MODEL_REMAP = {
    deepseek: {
        'claude-opus-4-6':    'deepseek-v4-pro',
        'claude-opus-4-7':    'deepseek-v4-pro',
        'claude-sonnet-4-6':  'deepseek-v4-flash',
        'claude-sonnet-4-5-20250929': 'deepseek-v4-flash',
        'claude-haiku-4-5-20251001':  'deepseek-v4-flash',
    },
    openrouter: {
        'claude-opus-4-6':    'deepseek/deepseek-v4-pro',
        'claude-opus-4-7':    'deepseek/deepseek-v4-pro',
        'claude-sonnet-4-6':  'deepseek/deepseek-v4-flash',
        'claude-sonnet-4-5-20250929': 'deepseek/deepseek-v4-flash',
        'claude-haiku-4-5-20251001':  'deepseek/deepseek-v4-flash',
    },
    codex: {
        'claude-opus-4-7':             'gpt-5.5',
        'claude-opus-4-6':             'gpt-5.5',
        'claude-sonnet-4-6':           'gpt-5.4',
        'claude-sonnet-4-5-20250929':  'gpt-5.4',
        'claude-haiku-4-5-20251001':   'gpt-5.4',
    },
};

const PRICING_PER_M = {
    deepseek:   { input: 0.44,  output: 0.87 },
    openrouter: { input: 0.44,  output: 0.87 },
    anthropic:  { input: 3.00,  output: 15.00 },
    _single:    { input: 0.44,  output: 0.87 },
};

/**
 * Transform stream that intercepts SSE events and injects missing `usage`
 * fields. DeepSeek/OpenRouter may omit `usage` in message_start or
 * message_delta, which crashes Claude Code ("$.input_tokens" is undefined).
 */
class UsageNormalizer extends Transform {
    constructor(onUsage, opts = {}) {
        super();
        this._buf = '';
        this._onUsage = onUsage;
        this._inputTokens = 0;
        this._outputTokens = 0;
        this._convertedThinkingIndexes = new Set();
        this._preserveThinking = !!opts.preserveThinking;
    }

    _transform(chunk, _enc, cb) {
        this._buf += chunk.toString();
        const parts = this._buf.split('\n\n');
        this._buf = parts.pop();
        for (const part of parts) {
            const fixed = this._fix(part);
            if (fixed) this.push(fixed + '\n\n');
        }
        cb();
    }

    _fix(event) {
        const m = event.match(/^data: (.+)$/m);
        if (!m) return event;
        try {
            const d = JSON.parse(m[1]);
            let changed = false;
            const thinkingEvent = this._normalizeThinkingEvent(d);
            if (thinkingEvent) {
                if (thinkingEvent === 'drop') return '';
                changed = true;
            }

            if (d.type === 'message_start' && d.message) {
                if (d.message.model && !d.message.model.endsWith('[1m]')) {
                    d.message.model += '[1m]';
                    changed = true;
                }
                if (d.message.usage) {
                    this._inputTokens = d.message.usage.input_tokens || 0;
                } else {
                    d.message.usage = { input_tokens: 0, output_tokens: 0 };
                    changed = true;
                }
            }
            if (d.type === 'message_delta') {
                if (d.usage) {
                    this._outputTokens = d.usage.output_tokens || 0;
                } else {
                    d.usage = { output_tokens: 0 };
                    changed = true;
                }
            }
            if (changed) return event.replace(m[1], () => JSON.stringify(d));
        } catch { /* not JSON, pass through */ }
        return event;
    }

    _normalizeThinkingEvent(d) {
        if (this._preserveThinking) return false;
        if (d.type === 'content_block_start' && isThinkingType(d.content_block?.type)) {
            this._convertedThinkingIndexes.add(d.index);
            d.content_block = { type: 'text', text: '' };
            return true;
        }
        if (!this._convertedThinkingIndexes.has(d.index) || d.type !== 'content_block_delta') {
            return false;
        }
        if (d.delta?.type === 'thinking_delta') {
            d.delta = { type: 'text_delta', text: d.delta.thinking || '' };
            return true;
        }
        if (d.delta?.type === 'signature_delta') return 'drop';
        return true;
    }

    _flush(cb) {
        if (this._buf.trim()) {
            const fixed = this._fix(this._buf);
            if (fixed) this.push(fixed + '\n\n');
        }
        if (this._onUsage) this._onUsage(this._inputTokens, this._outputTokens);
        cb();
    }
}

/**
 * For non-streaming JSON responses, ensure `usage` exists.
 */
function normalizeJsonBody(buf, opts = {}) {
    try {
        const obj = JSON.parse(buf);
        if (obj.model && !obj.model.endsWith('[1m]')) {
            obj.model += '[1m]';
        }
        if (obj.type === 'message' && !obj.usage) {
            obj.usage = { input_tokens: 0, output_tokens: 0 };
        }
        if (!opts.preserveThinking && obj.type === 'message' && Array.isArray(obj.content)) {
            obj.content = obj.content.map(convertThinkingBlockToText).filter(Boolean);
        }
        return Buffer.from(JSON.stringify(obj));
    } catch { /* not JSON */ }
    return buf;
}

function isThinkingType(type) {
    return type === 'thinking' || type === 'redacted_thinking';
}

function convertThinkingBlockToText(block) {
    if (!isThinkingType(block?.type)) return block;
    const text = block.thinking || block.text || '';
    return text ? { type: 'text', text } : null;
}

function stripAllThinkingBlocks(body) {
    if (!body?.messages) return;
    delete body.thinking;
    for (const msg of body.messages) {
        if (!Array.isArray(msg.content)) continue;
        msg.content = msg.content.filter(b => !isThinkingType(b.type));
    }
}

function stripUnsignedThinkingBlocks(body) {
    if (!body?.messages) return;
    for (const msg of body.messages) {
        if (!Array.isArray(msg.content)) continue;
        msg.content = msg.content.filter(
            block => !isThinkingType(block.type) || block.signature
        );
    }
}

function sessionFromHeaders(headers) {
    const explicit = headers['x-deepclaude-session'];
    if (explicit) return sanitizeSessionId(String(explicit));

    const auth = headers.authorization || headers.Authorization;
    const bearer = typeof auth === 'string' ? auth.match(/^Bearer\s+(.+)$/i)?.[1] : null;
    if (bearer?.startsWith('dcx_')) return sanitizeSessionId(bearer);

    const apiKey = headers['x-api-key'];
    if (typeof apiKey === 'string' && apiKey.startsWith('dcx_')) return sanitizeSessionId(apiKey);

    return null;
}

function sanitizeSessionId(value) {
    return /^[A-Za-z0-9._:-]{1,128}$/.test(value) ? value : null;
}

function parseControlBody(body) {
    const params = new URLSearchParams(body);
    const backend = params.get('backend') || body.match(/backend=([a-z]+)/)?.[1];
    const session = sanitizeSessionId(params.get('session') || '');
    const action = params.get('action') || '';
    const pidRaw = params.get('pid') || '';
    const pid = /^[1-9][0-9]*$/.test(pidRaw) ? Number(pidRaw) : null;
    return { action, backend, pid, session };
}

export function startModelProxy({ targetUrl, apiKey, startPort = 3200, backends, defaultMode, idleTtlMs = DEFAULT_IDLE_TTL_MS, sessionTtlMs = DEFAULT_SESSION_TTL_MS }) {
    return new Promise((resolve, reject) => {
        const initialTarget = new URL(targetUrl);
        const initialBearer = targetUrl.includes('openrouter');

        const allBackends = {};
        if (backends) {
            for (const [name, cfg] of Object.entries(backends)) {
                allBackends[name] = {
                    target: new URL(cfg.url),
                    apiKey: cfg.apiKey,
                    useBearer: cfg.url.includes('openrouter') || cfg.url.includes('openai'),
                };
            }
        }
        const initialName = defaultMode || (backends ? 'anthropic' : null);
        const startBackend = initialName && initialName !== 'anthropic' && allBackends[initialName];

        const state = {
            defaultMode: initialName || '_single',
            sessions: new Map(),
        };

        let reqCount = 0;
        let activeModelRequests = 0;
        let idleTimer = null;
        let lastActivity = Date.now();
        const t0Global = Date.now();
        const costs = {};

        function touchActivity() {
            lastActivity = Date.now();
            if (idleTimer) {
                clearTimeout(idleTimer);
                idleTimer = null;
            }
        }

        function armIdleTimer() {
            pruneDeadSessions();
            if (!idleTtlMs || idleTtlMs < 0 || activeModelRequests > 0 || liveSessionCount() > 0 || idleTimer) return;
            const delay = Math.max(0, idleTtlMs - (Date.now() - lastActivity));
            idleTimer = setTimeout(() => {
                idleTimer = null;
                pruneDeadSessions();
                if (activeModelRequests > 0) return;
                if (liveSessionCount() > 0) {
                    armIdleTimer();
                    return;
                }
                const idleFor = Date.now() - lastActivity;
                if (idleFor < idleTtlMs) {
                    armIdleTimer();
                    return;
                }
                console.error(`[MODEL-PROXY] Idle for ${Math.round(idleFor / 1000)}s; shutting down`);
                server.close(() => process.exit(0));
                setTimeout(() => process.exit(0), 1000).unref();
            }, delay);
            idleTimer.unref?.();
        }

        function beginModelRequest() {
            touchActivity();
            activeModelRequests++;
        }

        function endModelRequest() {
            activeModelRequests = Math.max(0, activeModelRequests - 1);
            touchActivity();
            armIdleTimer();
        }

        function resolveMode(mode) {
            if (mode === 'anthropic') {
                return { mode, target: new URL(ANTHROPIC_FALLBACK), apiKey: null, useBearer: false };
            }
            if (mode && mode !== '_single' && allBackends[mode]) {
                const b = allBackends[mode];
                return { mode, target: b.target, apiKey: b.apiKey, useBearer: b.useBearer };
            }
            return { mode: '_single', target: initialTarget, apiKey, useBearer: initialBearer };
        }

        function getSessionState(sessionId) {
            if (!sessionId) return { mode: state.defaultMode, hadNonAnthropicSession: false };
            if (!state.sessions.has(sessionId)) {
                state.sessions.set(sessionId, {
                    mode: state.defaultMode,
                    hadNonAnthropicSession: state.defaultMode !== 'anthropic' && state.defaultMode !== '_single',
                    lastSeen: Date.now(),
                    pid: null,
                });
            }
            return state.sessions.get(sessionId);
        }

        function pidIsAlive(pid) {
            if (!pid) return false;
            try {
                process.kill(pid, 0);
                return true;
            } catch {
                return false;
            }
        }

        function sessionIsLive(session) {
            if (session.pid) return pidIsAlive(session.pid);
            return sessionTtlMs > 0 && Date.now() - (session.lastSeen || 0) < sessionTtlMs;
        }

        function pruneDeadSessions() {
            for (const [sessionId, session] of state.sessions.entries()) {
                if (!sessionIsLive(session)) state.sessions.delete(sessionId);
            }
        }

        function liveSessionCount() {
            let count = 0;
            for (const session of state.sessions.values()) {
                if (sessionIsLive(session)) count++;
            }
            return count;
        }

        function updateSessionHeartbeat(sessionId, pid) {
            if (!sessionId) return { error: 'Missing session' };
            const session = getSessionState(sessionId);
            session.lastSeen = Date.now();
            if (pid) session.pid = pid;
            touchActivity();
            return { session: sessionId, live_sessions: liveSessionCount() };
        }

        function stopSession(sessionId) {
            if (!sessionId) return { error: 'Missing session' };
            state.sessions.delete(sessionId);
            touchActivity();
            armIdleTimer();
            return { session: sessionId, live_sessions: liveSessionCount() };
        }

        function recordUsage(backend, inputTokens, outputTokens, sessionId) {
            const key = sessionId || '_shared';
            if (!costs[key]) costs[key] = { input: 0, output: 0, requests: 0, backends: {} };
            costs[key].input += inputTokens || 0;
            costs[key].output += outputTokens || 0;
            costs[key].requests++;
            if (!costs[key].backends[backend]) costs[key].backends[backend] = { input: 0, output: 0, requests: 0 };
            costs[key].backends[backend].input += inputTokens || 0;
            costs[key].backends[backend].output += outputTokens || 0;
            costs[key].backends[backend].requests++;
        }

        function getCostSummary() {
            const summary = {};
            let totalActual = 0;
            let totalAnthropic = 0;
            for (const [sessionId, tokens] of Object.entries(costs)) {
                const sessionBackends = {};
                for (const [backend, usage] of Object.entries(tokens.backends || {})) {
                    const p = PRICING_PER_M[backend] || PRICING_PER_M._single;
                    const actual = (usage.input * p.input + usage.output * p.output) / 1_000_000;
                    sessionBackends[backend] = {
                        input_tokens: usage.input,
                        output_tokens: usage.output,
                        requests: usage.requests,
                        cost: +actual.toFixed(4),
                    };
                }
                const ap = PRICING_PER_M.anthropic;
                const actual = Object.values(sessionBackends).reduce((sum, b) => sum + b.cost, 0);
                const anthropicEq = (tokens.input * ap.input + tokens.output * ap.output) / 1_000_000;
                totalActual += actual;
                totalAnthropic += anthropicEq;
                summary[sessionId] = {
                    input_tokens: tokens.input,
                    output_tokens: tokens.output,
                    requests: tokens.requests,
                    cost: +actual.toFixed(4),
                    anthropic_equivalent: +anthropicEq.toFixed(4),
                    backends: sessionBackends,
                };
            }
            return {
                backends: summary,
                total_cost: +totalActual.toFixed(4),
                anthropic_equivalent: +totalAnthropic.toFixed(4),
                savings: +((totalAnthropic - totalActual).toFixed(4)),
            };
        }

        function switchMode(name, sessionId) {
            const targetState = sessionId ? getSessionState(sessionId) : state;
            if (name === 'anthropic') {
                const prev = sessionId ? targetState.mode : state.defaultMode;
                if (sessionId) targetState.mode = 'anthropic';
                else state.defaultMode = 'anthropic';
                return { mode: 'anthropic', previous: prev, session: sessionId || null };
            }
            const b = allBackends[name];
            if (!b) return { error: `Unknown backend: ${name}. Valid: anthropic, ${Object.keys(allBackends).join(', ')}` };
            if (!b.apiKey) return { error: `API key not set for ${name}` };
            const prev = sessionId ? targetState.mode : state.defaultMode;
            if (sessionId) {
                targetState.mode = name;
                targetState.hadNonAnthropicSession = true;
            } else {
                state.defaultMode = name;
            }
            return { mode: name, previous: prev, session: sessionId || null };
        }

        const server = createServer((clientReq, clientRes) => {
            const urlPath = clientReq.url.split('?')[0];

            // Control endpoints — /_proxy/* (never collides with /v1/*)
            if (urlPath.startsWith('/_proxy/')) {
                if (urlPath === '/_proxy/status') {
                    pruneDeadSessions();
                    const url = new URL(clientReq.url, 'http://127.0.0.1');
                    const sessionId = sanitizeSessionId(url.searchParams.get('session') || '') || sessionFromHeaders(clientReq.headers);
                    const sessionState = sessionId ? state.sessions.get(sessionId) : null;
                    clientRes.writeHead(200, { 'content-type': 'application/json' });
                    clientRes.end(JSON.stringify({
                        mode: sessionState?.mode || state.defaultMode,
                        default_mode: state.defaultMode,
                        session: sessionId,
                        sessions: state.sessions.size,
                        live_sessions: liveSessionCount(),
                        active_requests: activeModelRequests,
                        idle_ttl_seconds: idleTtlMs ? Math.round(idleTtlMs / 1000) : null,
                        session_ttl_seconds: sessionTtlMs ? Math.round(sessionTtlMs / 1000) : null,
                        idle_for_seconds: Math.round((Date.now() - lastActivity) / 1000),
                        uptime: Math.round((Date.now() - t0Global) / 1000),
                        requests: reqCount,
                    }));
                    return;
                }
                if (urlPath === '/_proxy/session' && clientReq.method === 'POST') {
                    const chunks = [];
                    let bodySize = 0;
                    clientReq.on('data', c => {
                        bodySize += c.length;
                        if (bodySize > 1024) { clientReq.destroy(); return; }
                        chunks.push(c);
                    });
                    clientReq.on('end', () => {
                        const { action, pid, session } = parseControlBody(Buffer.concat(chunks).toString());
                        const sessionId = session || sessionFromHeaders(clientReq.headers);
                        const result = action === 'stop' ? stopSession(sessionId) : updateSessionHeartbeat(sessionId, pid);
                        if (result.error) {
                            clientRes.writeHead(400, { 'content-type': 'application/json' });
                            clientRes.end(JSON.stringify(result));
                            return;
                        }
                        clientRes.writeHead(200, { 'content-type': 'application/json' });
                        clientRes.end(JSON.stringify(result));
                    });
                    return;
                }
                if (urlPath === '/_proxy/session' && clientReq.method !== 'POST') {
                    clientRes.writeHead(405, { 'content-type': 'application/json' });
                    clientRes.end(JSON.stringify({ error: 'Use POST' }));
                    return;
                }
                if (urlPath === '/_proxy/cost') {
                    clientRes.writeHead(200, { 'content-type': 'application/json' });
                    clientRes.end(JSON.stringify(getCostSummary()));
                    return;
                }
                if (urlPath === '/_proxy/mode' && clientReq.method === 'POST') {
                    const origin = clientReq.headers['origin'] || '';
                    if (origin && !origin.startsWith('http://127.0.0.1') && !origin.startsWith('http://localhost')) {
                        clientRes.writeHead(403, { 'content-type': 'application/json' });
                        clientRes.end(JSON.stringify({ error: 'Forbidden' }));
                        return;
                    }
                    const chunks = [];
                    let bodySize = 0;
                    clientReq.on('data', c => {
                        bodySize += c.length;
                        if (bodySize > 1024) { clientReq.destroy(); return; }
                        chunks.push(c);
                    });
                    clientReq.on('end', () => {
                        const body = Buffer.concat(chunks).toString();
                        const { backend, session } = parseControlBody(body);
                        const sessionId = session || sessionFromHeaders(clientReq.headers);
                        if (!backend) {
                            clientRes.writeHead(400, { 'content-type': 'application/json' });
                            clientRes.end(JSON.stringify({ error: 'Missing backend= in body' }));
                            return;
                        }
                        const result = switchMode(backend, sessionId);
                        if (result.error) {
                            clientRes.writeHead(400, { 'content-type': 'application/json' });
                            clientRes.end(JSON.stringify(result));
                            return;
                        }
                        console.error(`[MODEL-PROXY] Mode switched${sessionId ? ` (${sessionId})` : ' default'}: ${result.previous} → ${result.mode}`);
                        clientRes.writeHead(200, { 'content-type': 'application/json' });
                        clientRes.end(JSON.stringify(result));
                    });
                    return;
                }
                if (urlPath === '/_proxy/mode' && clientReq.method !== 'POST') {
                    clientRes.writeHead(405, { 'content-type': 'application/json' });
                    clientRes.end(JSON.stringify({ error: 'Use POST' }));
                    return;
                }
                clientRes.writeHead(404, { 'content-type': 'application/json' });
                clientRes.end(JSON.stringify({ error: 'Not found' }));
                return;
            }

            const sessionId = sessionFromHeaders(clientReq.headers);
            const sessionState = getSessionState(sessionId);
            const route = resolveMode(sessionState.mode);
            const isAnthropicMode = route.mode === 'anthropic';
            const isModelCall = !isAnthropicMode && MODEL_PATHS.includes(urlPath);
            const dest = isModelCall ? route.target : new URL(ANTHROPIC_FALLBACK);

            // Build upstream path. target.pathname may overlap with
            // clientReq.url (e.g. OpenRouter /api/v1 + /v1/messages).
            // Strip the shared prefix to avoid /api/v1/v1/messages.
            let fullPath;
            if (isModelCall) {
                const base = route.target.pathname.replace(/\/$/, '');
                let overlap = '';
                for (let i = 1; i <= Math.min(base.length, urlPath.length); i++) {
                    if (base.endsWith(urlPath.substring(0, i))) overlap = urlPath.substring(0, i);
                }
                fullPath = overlap ? base + urlPath.substring(overlap.length) : base + urlPath;
            } else {
                fullPath = clientReq.url;
            }

            const reqId = ++reqCount;
            const t0 = Date.now();
            let finishModelRequest = () => {};

            if (isModelCall) {
                console.error(`[MODEL-PROXY] #${reqId} ${sessionId || '_shared'}:${route.mode} → ${dest.hostname}${fullPath}`);
                beginModelRequest();
                let modelRequestDone = false;
                finishModelRequest = () => {
                    if (modelRequestDone) return;
                    modelRequestDone = true;
                    endModelRequest();
                };
                clientReq.on('aborted', finishModelRequest);
                clientRes.on('close', () => {
                    if (!clientRes.writableEnded) finishModelRequest();
                });
            }

            const headers = { ...clientReq.headers, host: dest.host };
            delete headers['content-length'];

            if (isModelCall) {
                delete headers['authorization'];
                delete headers['x-api-key'];
                if (route.mode !== 'deepseek') {
                    delete headers['anthropic-beta'];
                    delete headers['x-claude-code-effort-level'];
                }
                delete headers['x-stainless-retry-count'];
                if (route.useBearer) {
                    headers['authorization'] = `Bearer ${route.apiKey}`;
                } else {
                    headers['x-api-key'] = route.apiKey;
                }
            }

            const chunks = [];
            clientReq.on('data', c => chunks.push(c));
            clientReq.on('end', () => {
                let body = Buffer.concat(chunks);

                // Remap Anthropic model names to backend-specific names
                if (isModelCall && MODEL_REMAP[route.mode]) {
                    try {
                        const parsed = JSON.parse(body);
                        const mapped = MODEL_REMAP[route.mode][parsed.model];
                        if (mapped) {
                            console.error(`[MODEL-PROXY] #${reqId} model remap: ${parsed.model} → ${mapped}`);
                            parsed.model = mapped;
                            body = Buffer.from(JSON.stringify(parsed));
                        }
                    } catch { /* not JSON or parse error, pass through */ }
                }

                // Strip [1m] from model name before forwarding to backend.
                // [1m] is Claude Code's 1M-context signal — backends reject it.
                if (isModelCall) {
                    try {
                        const parsed = JSON.parse(body);
                        if (parsed.model && parsed.model.endsWith('[1m]')) {
                            parsed.model = parsed.model.slice(0, -4);
                            body = Buffer.from(JSON.stringify(parsed));
                        }
                    } catch { /* pass through */ }
                }

                // Strip thinking blocks before forwarding.
                // Non-Anthropic: strip ALL blocks — backends reject thinking blocks
                // they didn't generate, even unsigned ones.
                // Anthropic after a non-Anthropic session: also strip ALL, because
                // foreign backends generate signed-but-invalid thinking blocks that
                // stripUnsignedThinkingBlocks passes through, causing Anthropic 400s.
                if (isAnthropicMode && MODEL_PATHS.includes(urlPath)) {
                    try {
                        const parsed = JSON.parse(body);
                        if (sessionState.hadNonAnthropicSession) {
                            stripAllThinkingBlocks(parsed);
                        } else {
                            stripUnsignedThinkingBlocks(parsed);
                        }
                        body = Buffer.from(JSON.stringify(parsed));
                    } catch { /* pass through */ }
                }
                if (isModelCall) {
                    try {
                        const parsed = JSON.parse(body);
                        if (route.mode !== 'deepseek') {
                            delete parsed.reasoning;
                            delete parsed.reasoning_effort;
                            delete parsed.thinking_budget;
                            stripAllThinkingBlocks(parsed);
                        }
                        body = Buffer.from(JSON.stringify(parsed));
                    } catch { /* pass through */ }
                }

                // Codex/OpenAI: rewrite path from /v1/messages → /v1/chat/completions
                if (route.mode === 'codex') {
                    fullPath = '/v1/chat/completions';
                }

                const opts = {
                    hostname: dest.hostname,
                    port: dest.port || 443,
                    path: fullPath,
                    method: clientReq.method,
                    headers: { ...headers, 'content-length': body.length },
                    timeout: REQUEST_TIMEOUT_MS,
                };

                const proxyReq = httpsRequest(opts, (proxyRes) => {
                    if (isModelCall) {
                        const ttfb = Date.now() - t0;
                        console.error(`[MODEL-PROXY] #${reqId} TTFB ${ttfb}ms (status ${proxyRes.statusCode})`);
                    }

                    const ct = proxyRes.headers['content-type'] || '';
                    const isSSE = ct.includes('text/event-stream');

                    if (isModelCall && isSSE) {
                        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
                        const norm = new UsageNormalizer(
                            (inp, out) => recordUsage(route.mode, inp, out, sessionId),
                            { preserveThinking: route.mode === 'deepseek' }
                        );
                        if (route.mode === 'codex') {
                            const codexSSE = new CodexResponseSSE();
                            proxyRes.pipe(codexSSE).pipe(norm).pipe(clientRes);
                        } else {
                            proxyRes.pipe(norm).pipe(clientRes);
                        }
                        proxyRes.on('end', () => {
                            console.error(`[MODEL-PROXY] #${reqId} done in ${((Date.now() - t0) / 1000).toFixed(1)}s (${norm._inputTokens}in/${norm._outputTokens}out)`);
                            finishModelRequest();
                        });
                    } else if (isModelCall && ct.includes('application/json')) {
                        const respChunks = [];
                        proxyRes.on('data', c => respChunks.push(c));
                        proxyRes.on('end', () => {
                            const raw = Buffer.concat(respChunks);
                            const fixed = normalizeJsonBody(raw, { preserveThinking: route.mode === 'deepseek' });
                            try {
                                const j = JSON.parse(fixed);
                                if (j.usage) recordUsage(route.mode, j.usage.input_tokens, j.usage.output_tokens, sessionId);
                            } catch {}
                            const outHeaders = { ...proxyRes.headers, 'content-length': fixed.length };
                            clientRes.writeHead(proxyRes.statusCode, outHeaders);
                            clientRes.end(fixed);
                            console.error(`[MODEL-PROXY] #${reqId} done in ${((Date.now() - t0) / 1000).toFixed(1)}s (json, ${fixed.length}b)`);
                            finishModelRequest();
                        });
                    } else {
                        // Non-model or unknown content-type: pass through
                        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
                        proxyRes.pipe(clientRes);
                        if (isModelCall) {
                            proxyRes.on('end', () => {
                                console.error(`[MODEL-PROXY] #${reqId} done in ${((Date.now() - t0) / 1000).toFixed(1)}s`);
                                finishModelRequest();
                            });
                        }
                    }
                });

                proxyReq.on('timeout', () => {
                    console.error(`[MODEL-PROXY] #${reqId} TIMEOUT after ${REQUEST_TIMEOUT_MS / 1000}s`);
                    proxyReq.destroy(new Error('Request timeout'));
                });

                proxyReq.on('error', (err) => {
                    const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
                    console.error(`[MODEL-PROXY] #${reqId} ERROR after ${elapsed}s: ${err.message}`);
                    if (!clientRes.headersSent) {
                        clientRes.writeHead(502, { 'content-type': 'application/json' });
                    }
                    clientRes.end(JSON.stringify({ error: { message: 'Upstream connection error' } }));
                    finishModelRequest();
                });

                proxyReq.end(body);
            });
        });

        function tryListen(port) {
            server.once('error', (err) => {
                if (err.code === 'EADDRINUSE' && port < startPort + 20) {
                    tryListen(port + 1);
                } else {
                    reject(err);
                }
            });
            server.listen(port, '127.0.0.1', () => {
                const actualPort = server.address().port;
                console.error(`[MODEL-PROXY] Listening on 127.0.0.1:${actualPort} → ${targetUrl} (default mode: ${state.defaultMode})`);
                armIdleTimer();
                resolve({ port: actualPort, close: () => server.close(), switchMode });
            });
        }

        tryListen(startPort);
    });
}
