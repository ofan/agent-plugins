// translate-openai.js — Anthropic SSE reconstruction from OpenAI chunk stream
//
// Response side: reconstruct Anthropic's block-structured SSE events from OpenAI's
// flat delta stream. Request side is thin — model remap + auth swap.
//
// Usage:
//   const codex = new CodexResponseSSE();
//   openaiRes.pipe(codex).pipe(usageNormalizer).pipe(clientRes);

import { Transform } from 'stream';

const MODEL_REMAP = {
    'claude-opus-4-7':             'gpt-5.5',
    'claude-opus-4-6':             'gpt-5.5',
    'claude-sonnet-4-6':           'gpt-5.4',
    'claude-sonnet-4-5-20250929':  'gpt-5.4',
    'claude-haiku-4-5-20251001':   'gpt-5.4',
};

export function mapCodexRequest(anthropicReq) {
    const body = JSON.parse(anthropicReq.body);
    const remappedModel = MODEL_REMAP[body.model] || body.model;
    body.model = remappedModel;

    return {
        url: new URL('/v1/chat/completions', anthropicReq.url),
        headers: {
            'Authorization': `Bearer ${anthropicReq.headers.get('x-api-key') || ''}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
    };
}

export class CodexResponseSSE extends Transform {
    constructor() {
        super();
        this._buf = '';
        this._started = false;
        this._contentIdx = 0;
        this._model = '';
        this._msgId = '';
        this._outputTokens = 0;
        this._inputTokens = 0;
        this._openTools = new Map();
    }

    _emit(type, data) {
        return `data: ${JSON.stringify({ type, ...data })}\n\n`;
    }

    _transform(chunk, _enc, cb) {
        this._buf += chunk.toString();
        const parts = this._buf.split('\n\n');
        this._buf = parts.pop();
        for (const part of parts) {
            const lines = part.split('\n');
            for (const line of lines) {
                if (!line.startsWith('data: ')) continue;
                if (line === 'data: [DONE]') {
                    this.push(this._finalize());
                    continue;
                }
                try {
                    const d = JSON.parse(line.slice(6));
                    const events = this._convert(d);
                    if (events) this.push(events);
                } catch (_) { /* skip */ }
            }
        }
        cb();
    }

    _flush(cb) {
        if (this._buf.trim()) {
            // Process any remaining buffered data
            for (const line of this._buf.split('\n')) {
                if (!line.startsWith('data: ')) continue;
                if (line === 'data: [DONE]') {
                    this.push(this._finalize());
                    continue;
                }
                try {
                    const d = JSON.parse(line.slice(6));
                    const events = this._convert(d);
                    if (events) this.push(events);
                } catch (_) {}
            }
        }
        cb();
    }

    _convert(d) {
        let result = '';
        if (!d.choices || !d.choices[0]) return result;
        const choice = d.choices[0];
        const delta = choice.delta || {};

        if (d.model && !this._started) {
            this._model = d.model;
            this._msgId = d.id || 'msg_' + Date.now();
        }

        // message_start on first content-bearing chunk
        if (!this._started && (delta.content || delta.tool_calls)) {
            this._started = true;
            result += this._emit('message_start', {
                message: {
                    id: this._msgId,
                    type: 'message',
                    role: 'assistant',
                    model: this._model + '[1m]',
                    content: [],
                    usage: { input_tokens: 0, output_tokens: 0 },
                },
            });
        }

        // Text content
        if (delta.content) {
            // If we just had tool calls open, close them
            if (this._openTools.size > 0) {
                for (const [idx] of this._openTools) {
                    result += this._emit('content_block_delta', {
                        index: idx,
                        delta: { type: 'input_json_delta', partial_json: '' },
                    });
                    result += this._emit('content_block_stop', { index: idx });
                }
                this._openTools.clear();
            }
            result += this._emit('content_block_delta', {
                index: this._contentIdx,
                delta: { type: 'text_delta', text: delta.content },
            });
        }

        // Tool calls
        if (delta.tool_calls) {
            for (const tc of delta.tool_calls) {
                if (tc.index == null) continue;
                const existing = this._openTools.get(tc.index);

                // New tool call
                if (!existing && tc.id) {
                    const name = tc.function?.name || '';
                    const anthropicIdx = this._contentIdx + tc.index;
                    this._openTools.set(tc.index, { id: tc.id, name });
                    // Close any text block so tool_use gets correct index
                    if (this._contentIdx === 0 && tc.index === 0 && this._started) {
                        // first tool block, text didn't start
                    }
                    result += this._emit('content_block_start', {
                        index: anthropicIdx,
                        content_block: {
                            type: 'tool_use',
                            id: tc.id,
                            name: name,
                            input: {},
                        },
                    });
                }

                // Tool arguments (streamed as JSON fragments)
                if (tc.function?.arguments) {
                    const anthropicIdx = this._contentIdx + tc.index;
                    result += this._emit('content_block_delta', {
                        index: anthropicIdx,
                        delta: {
                            type: 'input_json_delta',
                            partial_json: tc.function.arguments,
                        },
                    });
                }
            }
        }

        // Finish and usage
        if (choice.finish_reason) {
            if (d.usage) {
                this._outputTokens = d.usage.completion_tokens || 0;
                this._inputTokens = d.usage.prompt_tokens || 0;
            }
            const stopMap = {
                'stop': 'end_turn',
                'tool_calls': 'tool_use',
                'length': 'max_tokens',
                'content_filter': 'content_filter',
            };
            result += this._emit('message_delta', {
                delta: { stop_reason: stopMap[choice.finish_reason] || choice.finish_reason },
                usage: { output_tokens: this._outputTokens },
            });
        }

        return result;
    }

    _finalize() {
        let result = '';
        // Close any open tool blocks
        for (const [idx] of this._openTools) {
            result += this._emit('content_block_stop', { index: idx });
        }
        this._openTools.clear();
        result += this._emit('message_stop', {});
        return result;
    }
}
